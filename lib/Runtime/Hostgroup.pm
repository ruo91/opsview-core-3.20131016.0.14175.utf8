#
#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

package Runtime::Hostgroup;
use base ( qw(Runtime Runtime::Action Utils::ContextSave) );
use Opsview::Externalcommand;
use Opsview::Auditlog;

use strict;

__PACKAGE__->table( "opsview_hostgroups" );

__PACKAGE__->columns( Primary   => qw/id/ );
__PACKAGE__->columns( Essential => qw/name parentid lft rgt matpath/ );

__PACKAGE__->has_a( parentid => 'Runtime::Hostgroup' );

__PACKAGE__->default_search_attributes( { order_by => "name" } );

# This returns a list of leaves, ie, hostgroups at the bottom of the hierarchical tree
__PACKAGE__->set_sql( leaves => <<"" );
SELECT h.id
FROM __TABLE__ h
LEFT JOIN __TABLE__ h2
ON (h.id=h2.parentid)
WHERE h2.id IS NULL
ORDER BY h.name


=head1 NAME

Runtime::Hostgroup - Accessing opsview_hostgroups table

=head1 DESCRIPTION

Handles interaction with database for Runtime's hostgroup information

This is a copy of Opsview::Hostgroup, synchronised at reload time. Needs to be 
separate so that changes to O::H do not affect currently running status views.

Don't worry about constraints and the like because O::H should take care of all 
of that.

=head1 METHODS

=item $self->children

Returns all children of this hostgroup

=cut

sub children {
    my $self = shift;
    return ( $self->search( parentid => $self->id ) );
}

=item $self->is_leaf

Will return true if this is a leaf. 

=cut

sub is_leaf {
    my $self = shift;
    return ( $self->lft + 1 == $self->rgt );
}

=item $self->leaves

Will return an array of leaves from this point of the hostgroup onwards

=cut

# TODO: This could be sped up big time using a single query!!!!
sub leaves {
    my $self = shift;
    my @leaves;
    if ( $self->is_leaf ) {
        return $self;
    }
    else {
        foreach my $c ( $self->children ) {
            push @leaves, $c->leaves;
        }
    }
    return @leaves;
}

=item list_all_hosts

Returns a list of all hosts within the hostgroup

=cut

sub list_all_hosts {
    my ( $self, $user ) = @_;

    my $contact_join  = "";
    my $contact_where = "";
    if ( $user->has_access("VIEWSOME") ) {
        $contact_join =
          "INNER JOIN opsview_contact_objects ON (ohgh.host_object_id=opsview_contact_objects.object_id)";
        $contact_where = "AND opsview_contact_objects.contactid = " . $user->id;
    }

    my $sql = "
SELECT
  host_object_id AS id
FROM 
  opsview_hostgroups h
LEFT JOIN opsview_hostgroup_hosts ohgh ON (ohgh.hostgroup_id=h.id)
$contact_join
WHERE
  h.lft >= ?
AND  
  h.rgt <= ?
AND
  host_object_id IS NOT NULL
$contact_where
GROUP BY ohgh.host_object_id
";

    my $sth = $self->db_Main->prepare_cached($sql);

    return Runtime::Host->sth_to_objects( $sth, [ $self->lft, $self->rgt ] );
}

=item list_all_services

Returns a list of all services within the hostgroup

=cut

sub list_all_services {
    my ( $self, $user ) = @_;

    my $contact_join  = "";
    my $contact_where = "";
    if ( $user->has_access("VIEWSOME") ) {
        $contact_join =
          "INNER JOIN opsview_contact_services ON (ohs.service_object_id=opsview_contact_services.service_object_id)";
        $contact_where =
          "AND opsview_contact_services.contactid = " . $user->id;
    }

    my $sql = "
SELECT 
  ohs.service_object_id
FROM
  opsview_hostgroups h
LEFT JOIN opsview_hostgroup_hosts ohgh ON (ohgh.hostgroup_id=h.id)
LEFT JOIN opsview_host_services ohs ON (ohs.host_object_id=ohgh.host_object_id)
$contact_join
WHERE
  h.lft >= ?
AND  
  h.rgt <= ?
AND
  ohs.service_object_id IS NOT NULL
$contact_where
GROUP BY ohs.service_object_id
";

    my $sth = $self->db_Main->prepare_cached($sql);

    return Runtime::Service->sth_to_objects( $sth, [ $self->lft, $self->rgt ]
    );
}

=item list_all_hosts_with_downtime 

Returns a list of all hosts within the hostgroup with scheduled downtime

=cut

sub list_all_hosts_with_downtime {
    my ( $self, $user ) = @_;

    my $contact_join  = "";
    my $contact_where = "";
    if ( $user->has_access("VIEWSOME") ) {
        $contact_join =
          "INNER JOIN opsview_contact_objects ON (oh.id=opsview_contact_objects.object_id)";
        $contact_where = "AND opsview_contact_objects.contactid = " . $user->id;
    }

    # seperate sql to list_all_hosts as should be faster in one query
    my $sql = "
SELECT
  nsd.scheduleddowntime_id
FROM
  opsview_hostgroups h
LEFT JOIN opsview_hostgroup_hosts ohgh ON (ohgh.hostgroup_id=h.id)
LEFT JOIN nagios_scheduleddowntime nsd ON (nsd.object_id = ohgh.host_object_id)
LEFT JOIN opsview_hosts oh ON (oh.opsview_host_id = ohgh.host_object_id)
$contact_join
WHERE
  h.lft >= ?
AND  
  h.rgt <= ?
AND
  nsd.downtime_type=2
$contact_where
GROUP BY ohgh.host_object_id
ORDER BY nsd.scheduled_start_time,nsd.comment_data,ohgh.host_object_id
";

    my $sth = $self->db_Main->prepare_cached($sql);

    return Runtime::Hostdowntime->sth_to_objects( $sth,
        [ $self->lft, $self->rgt ] );
}

=item list_all_services_with_downtime 

Returns a list of all services within the hostgroup with scheduled downtime

=cut

sub list_all_services_with_downtime {
    my ( $self, $user ) = @_;

    my $contact_join  = "";
    my $contact_where = "";
    if ( $user->has_access("VIEWSOME") ) {
        $contact_join =
          "INNER JOIN opsview_contact_services ON (ohs.service_object_id=opsview_contact_services.service_object_id)";
        $contact_where =
          "AND opsview_contact_services.contactid = " . $user->id;
    }

    # seperate sql to list_all_services as should be faster in one query
    my $sql = "
SELECT
  nsd.scheduleddowntime_id
FROM
  opsview_hostgroups h
LEFT JOIN opsview_hostgroup_hosts ohgh ON (ohgh.hostgroup_id=h.id)
LEFT JOIN opsview_host_services ohs ON (ohs.host_object_id=ohgh.host_object_id)
LEFT JOIN nagios_scheduleddowntime nsd ON (nsd.object_id = ohs.service_object_id)
LEFT JOIN opsview_hosts oh ON (oh.opsview_host_id = ohgh.host_object_id)
$contact_join
WHERE
  h.lft >= ?
AND  
  h.rgt <= ?
AND
  nsd.downtime_type=1
$contact_where
GROUP BY ohs.service_object_id
ORDER BY nsd.scheduled_start_time,nsd.comment_data,ohgh.host_object_id,ohs.servicename
";

    my $sth = $self->db_Main->prepare_cached($sql);

    return Runtime::Servicedowntime->sth_to_objects( $sth,
        [ $self->lft, $self->rgt ]
    );
}

=item list_all_hostgroup_downtime_by_comment

Returns a list of all downtime for the hostgroups, grouped by comment and
entry_time

=cut

sub list_all_hostgroup_downtime_by_comment {
    my ( $self, $user ) = @_;

    my $contact_join  = "";
    my $contact_where = "";
    if ( $user->has_access("VIEWSOME") ) {
        $contact_join =
          "INNER JOIN opsview_contact_objects ON (nsd.object_id=opsview_contact_objects.object_id)";
        $contact_where = "AND opsview_contact_objects.contactid = " . $user->id;
    }

    # Need to check scheduled downtime is applicable for hosts or services
    my $sql = "
SELECT nsd.scheduleddowntime_id
FROM
  opsview_hostgroups h
LEFT JOIN opsview_hostgroup_hosts ohgh ON (ohgh.hostgroup_id=h.id)
LEFT JOIN opsview_host_services ohs ON (ohs.host_object_id=ohgh.host_object_id)
LEFT JOIN nagios_scheduleddowntime nsd ON (nsd.object_id = ohs.service_object_id OR nsd.object_id = ohs.host_object_id)
$contact_join
WHERE
  h.lft >= ?
AND
  h.rgt <= ?
AND 
	nsd.scheduleddowntime_id IS NOT NULL
$contact_where
GROUP BY nsd.comment_data,nsd.entry_time
ORDER BY nsd.comment_data,nsd.scheduled_start_time
";

    my $sth = $self->db_Main->prepare_cached($sql);
    return Runtime::Downtime->sth_to_objects( $sth, [ $self->lft, $self->rgt ]
    );
}

=item $self->notifications( $state )

Will set notifications for this hostgroup to $state, where $state is enable or disable

Will change all leaves of this hostgroup (possibly in the hierarchy)

=cut

sub notifications {
    my ( $self, $state ) = @_;
    if ( $state eq "enable" ) {
        $state = "ENABLE";
    }
    else {
        $state = "DISABLE";
    }

    eval {
        foreach my $hg ( $self->leaves )
        {
            my $cmd = Opsview::Externalcommand->new(
                command => "${state}_HOSTGROUP_SVC_NOTIFICATIONS",
                args    => $hg->name,
            );
            $cmd->submit;
            $cmd = Opsview::Externalcommand->new(
                command => "${state}_HOSTGROUP_HOST_NOTIFICATIONS",
                args    => $hg->name,
            );
            $cmd->submit;
        }
    };
    return $@ ? undef : 1;
}

=item $self->downtime( { start => $start, end => $end, comment => $comment } )

Will set up (if hash passed) or cancel (if no hash) scheduled downtime for 
the hostgroup.  Both $start end $end are times in epoch format and should 
have been previously validated.

Will affect all leaf hostgroups contained within this (possibly hierarchical) hostgroup.

Returns true if successful, otherwise sets $@ to error

=cut

sub downtime {
    my ( $self, $config ) = @_;
    my $author = $self->username;

    if ( ref($config) eq "HASH" ) {

        # enable

        my $start = $config->{start};
        my $end   = $config->{end};

        # TODO: Should work out i18n, but requires context for this
        Opsview::Auditlog->create(
            {
                username => $author,
                text     => "Downtime scheduled for host group '"
                  . $self->name
                  . "': starting "
                  . scalar localtime($start)
                  . ", ending "
                  . scalar localtime($end) . ": "
                  . $config->{comment},
            }
        );

        eval {
            foreach my $hg ( $self->leaves )
            {
                my $comment =
                  "Host group '" . $hg->name . "': " . $config->{comment};
                my $cmd = Opsview::Externalcommand->new(
                    command => "SCHEDULE_HOSTGROUP_SVC_DOWNTIME",
                    args    => $hg->name . ";$start;$end;1;0;;$author;$comment",
                );
                $cmd->submit;
                $cmd = Opsview::Externalcommand->new(
                    command => "SCHEDULE_HOSTGROUP_HOST_DOWNTIME",
                    args    => $hg->name . ";$start;$end;1;0;;$author;$comment",
                );
                $cmd->submit;
            }
        };
    }
    else {

        # disable
        Opsview::Auditlog->create(
            {
                username => $author,
                text     => "Downtime deleted for host group " . $self->name,
            }
        );

        eval {
            foreach my $hg ( $self->leaves )
            {
                my $cmd = Opsview::Externalcommand->new(
                    command => "DEL_HOSTGROUP_SVC_DOWNTIME",
                    args    => $hg->name,
                );
                $cmd->submit;
                $cmd = Opsview::Externalcommand->new(
                    command => "DEL_HOSTGROUP_HOST_DOWNTIME",
                    args    => $hg->name,
                );
                $cmd->submit;
            }
        };
    }
    return 1 unless ($@);
    return undef;
}

=item $self->host_status_ref

Returns a hashref of structure: $h->{status}->{unhandled} = total

=cut

# Can't use bind vars because only for scalar values, not lists
# Could use subquery in future enhancement
sub host_status_ref {
    my $self        = shift;
    my $host_status = {};
    my @hgs         = map { $_->name } $self->leaves;
    my $hg_list     = '("' . join( '","', @hgs ) . '")';
    my $statement   = "
select hs.current_state as host_status,
 (hs.current_state != 0 and hs.problem_has_been_acknowledged != 1 and hs.scheduled_downtime_depth = 0) as unhandled,
 count(hs.current_state) as total
from nagios_objects o3, nagios_objects o4,
 nagios_hoststatus hs,
 nagios_hostgroup_members hgm, nagios_hostgroups hg
where o3.objecttype_id = 1
and o3.object_id = hs.host_object_id
and hs.host_object_id = hgm.host_object_id
and hs.has_been_checked = 1
and hg.hostgroup_id = hgm.hostgroup_id
and o4.name1 in $hg_list
and o4.objecttype_id=3
and o4.object_id = hg.hostgroup_object_id
group by host_status, unhandled
";
    my $dbh = Runtime->db_Main;
    my $sth = $dbh->prepare_cached($statement);
    $sth->execute;
    my $handled   = 0;
    my $unhandled = 0;

    while ( my $hash = $sth->fetchrow_hashref ) {
        my $key;
        if ( $hash->{unhandled} ) {
            $key = "unhandled";
            $unhandled += $hash->{total};
        }
        else {
            $key = "handled";
            $handled += $hash->{total};
        }
        $host_status->{ $hash->{host_status} }->{$key} = $hash->{total};
    }
    $host_status->{unhandled} = $unhandled;
    $host_status->{handled}   = $handled;
    $host_status->{total}     = $handled + $unhandled;
    return $host_status;
}

=item $self->service_status_ref($contact_name)

Returns a hashref of structure: $h->{statuscode}->{(un)?handled} = total

=cut

# Can't use bind vars because only for scalar values, not lists
sub service_status_ref {
    my ( $self, $contact_name ) = @_;
    my $service_status = {};
    my @hgs            = map { $_->name } $self->leaves;
    my $hg_list        = '("' . join( '","', @hgs ) . '")';
    my $statement      = "
select
 ss.current_state as state,
 (ss.current_state != 0 and hs.current_state = 0 and ss.problem_has_been_acknowledged!=1 and hs.scheduled_downtime_depth=0) as unhandled,
 count(*) as total
from nagios_objects o, nagios_objects o2, nagios_objects o3, nagios_objects o4,
 nagios_contactgroup_members cgm, nagios_contactgroups cg,
 nagios_service_contactgroups scg, nagios_services s, nagios_servicestatus ss, nagios_hoststatus hs,
 nagios_hostgroup_members hgm, nagios_hostgroups hg
where o.name1='$contact_name'
and o.objecttype_id=10
and o.object_id = cgm.contact_object_id
and cgm.contactgroup_id = cg.contactgroup_id
and cg.config_type = 1
and cg.contactgroup_object_id = scg.contactgroup_object_id
and scg.service_id = s.service_id
and s.service_object_id = ss.service_object_id
and s.config_type = 1
and o2.object_id = s.service_object_id
and o2.name1 = o3.name1
and o3.objecttype_id = 1
and o3.object_id = hs.host_object_id
and hs.host_object_id = hgm.host_object_id
and hg.hostgroup_id = hgm.hostgroup_id
and o4.name1 in $hg_list
and o4.objecttype_id=3
and o4.object_id = hg.hostgroup_object_id
group by state, unhandled;
";
    my $dbh = Runtime->db_Main;
    my $sth = $dbh->prepare_cached($statement);
    $sth->execute;
    my $handled   = 0;
    my $unhandled = 0;

    while ( my $hash = $sth->fetchrow_hashref ) {
        my $key;
        if ( $hash->{unhandled} ) {
            $key = "unhandled";
            $unhandled += $hash->{total};
        }
        else {
            $key = "handled";
            $handled += $hash->{total};
        }
        $service_status->{ $hash->{state} }->{$key} = $hash->{total};
    }
    $service_status->{unhandled} = $unhandled;
    $service_status->{handled}   = $handled;
    $service_status->{total}     = $handled + $unhandled;
    return $service_status;
}

=item $self->host_service_status_ref($contact_name)

Returns a hashref of structure: $hash->{$host}->{host_state} = {$host_status},
				$hash->{$host}->{services}->{handled} = ?
				$hash->{$host}->{services}->{unhandled} = ?
				$hash->{$host}->{services}->{total} = ?
				$hash->{$host}->{services}->{$service_state}->{(un)?handled} = $total
				$hash->{$host}->{name} = $host

=cut

# Can't use bind vars because only for scalar values, not lists
sub host_service_status_ref {
    my ( $self, $contact_name ) = @_;
    my $host_service_status = {};
    my $hg_name             = $self->name;
    my $statement           = "
select
 o_host.name1 as host,
 hs.current_state as host_state,
 ss.current_state as service_state,
 (ss.current_state != 0 and hs.current_state = 0 and ss.problem_has_been_acknowledged!=1 and hs.scheduled_downtime_depth=0) as unhandled,
 count(*) as total
from nagios_objects o_contact, nagios_objects o_service, nagios_objects o_host, nagios_objects o_hg,
 nagios_contactgroup_members cgm, nagios_contactgroups cg,
 nagios_service_contactgroups scg, nagios_services s, nagios_servicestatus ss, nagios_hoststatus hs,
 nagios_hostgroup_members hgm, nagios_hostgroups hg
where 
 o_contact.name1='$contact_name'
 and o_contact.objecttype_id=10
 and o_contact.object_id = cgm.contact_object_id
 and cgm.contactgroup_id = cg.contactgroup_id
 and cg.config_type = 1
 and cg.contactgroup_object_id = scg.contactgroup_object_id
 and scg.service_id = s.service_id
 and s.config_type = 1
 and s.service_object_id = ss.service_object_id
 and o_service.object_id = s.service_object_id
 and o_service.name1 = o_host.name1
 and o_host.objecttype_id = 1
 and o_host.object_id = hs.host_object_id
 and hs.host_object_id = hgm.host_object_id
 and hg.hostgroup_id = hgm.hostgroup_id
 and o_hg.name1 = '$hg_name'
 and o_hg.objecttype_id=3
 and o_hg.object_id = hg.hostgroup_object_id
group by host, service_state, unhandled
";
    my $dbh = Runtime->db_Main;
    my $sth = $dbh->prepare_cached($statement);
    $sth->execute;
    my $host      = "";
    my $handled   = 0;
    my $unhandled = 0;

    while ( my $hash = $sth->fetchrow_hashref ) {
        my $key;
        if ( $hash->{unhandled} ) {
            $key = "unhandled";
            $unhandled += $hash->{total};
        }
        else {
            $key = "handled";
            $handled += $hash->{total};
        }
        if ( $host ne $hash->{host} ) {
            if ($host) {
                $host_service_status->{$host}->{host} = $host;
                $host_service_status->{$host}->{services}->{unhandled} =
                  $unhandled;
                $host_service_status->{$host}->{services}->{handled} = $handled;
                $host_service_status->{$host}->{services}->{total} =
                  $handled + $unhandled;
            }
            $host = $hash->{host};
            $host_service_status->{$host}->{host_state} = $hash->{host_state};
        }
        $host_service_status->{$host}->{services}->{ $hash->{service_state} }
          ->{$key} = $hash->{total};
    }

    # Need a nice way of not duplicating this with above
    $host_service_status->{$host}->{host}                  = $host;
    $host_service_status->{$host}->{services}->{unhandled} = $unhandled;
    $host_service_status->{$host}->{services}->{handled}   = $handled;
    $host_service_status->{$host}->{services}->{total} = $handled + $unhandled;

    my @a =
      map { $host_service_status->{$_} } ( sort keys %$host_service_status );
    return \@a;

    sub set_final_host_info {
    }
}

=item $obj->can_be_changed_by($contact_obj) 

Check whether or not the given contact has permisions on the object

Returns the object if true, undef if false

=cut

sub can_be_changed_by {
    my ( $self, $contact_obj ) = @_;

    # Note: only ACTIONALL users have this permission
    if ( $contact_obj->has_access("ACTIONALL") ) {
        return $self;
    }
    return;
}

=item $obj->can_set_downtime_by($contact_obj) 

Check whether or not the given contact has permisions to set downtime on the object

Returns true or false

=cut

sub can_set_downtime_by {
    my ( $self, $contact_obj ) = @_;

    # Note: only DOWNTIMEALL users can set downtime on hostgroups currently
    # as it affects all hosts underneath
    if ( $contact_obj->has_access("DOWNTIMEALL") ) {
        return $self;
    }
    return;
}

# Should this be in controller?
sub my_object_uri {
    my ( $self, $c ) = @_;

    # Remove object filters because this takes us to the host group itself
    $c->uri_for_params_status(
        "/status/hostgroup/" . $self->id,
        {}, [qw(host servicecheck hostgroupid)]
    );
}

=item my_type_is

Returns "hostgroup"

=cut

sub my_type_is {
    return "hostgroup";
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
