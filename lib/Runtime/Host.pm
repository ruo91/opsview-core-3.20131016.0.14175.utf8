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

package Runtime::Host;
use base 'Runtime';
use base ( qw(Runtime::Action Utils::ContextSave) );
use Opsview::Externalcommand;
use Opsview::Auditlog;

use strict;

__PACKAGE__->table( "opsview_hosts" );

__PACKAGE__->columns( Primary   => qw/id/ );
__PACKAGE__->columns( Essential => qw/name opsview_host_id ip/ );
__PACKAGE__->columns( Others    => qw/monitored_by/ );

__PACKAGE__->might_have( hoststatus => "Runtime::Hoststatus" =>
      qw(current_state output last_check scheduled_downtime_depth problem_has_been_acknowledged)
);
__PACKAGE__->has_a( opsview_host_id => "Opsview::Host" );

__PACKAGE__->default_search_attributes( { order_by => "name" } );

=head1 NAME

Runtime::Host - Accessing opsview_hosts table

=head1 DESCRIPTION

Handles interaction with database for Runtime's host information

This links with opsview.hosts table

=head1 METHODS

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
                text     => "Downtime scheduled for host "
                  . $self->name
                  . ": starting "
                  . scalar localtime($start)
                  . ", ending "
                  . scalar localtime($end) . ": "
                  . $config->{comment},
            }
        );

        eval {
            my $comment = "Host '" . $self->name . "': " . $config->{comment};
            my $cmd     = Opsview::Externalcommand->new(
                command => "SCHEDULE_HOST_SVC_DOWNTIME",
                args    => $self->name . ";$start;$end;1;0;;$author;$comment",
            );
            $cmd->submit;
            $cmd = Opsview::Externalcommand->new(
                command => "SCHEDULE_HOST_DOWNTIME",
                args    => $self->name . ";$start;$end;1;0;;$author;$comment",
            );
            $cmd->submit;
        };
    }
    else {

        # disable
        Opsview::Auditlog->create(
            {
                username => $author,
                text     => "Downtime deleted for host " . $self->name,
            }
        );

        eval {
            my $cmd = Opsview::Externalcommand->new(
                command => "DEL_HOST_SVC_DOWNTIME",
                args    => $self->name,
            );
            $cmd->submit;
            $cmd = Opsview::Externalcommand->new(
                command => "DEL_HOST_DOWNTIME",
                args    => $self->name,
            );
            $cmd->submit;
        };
    }
    return 1 unless ($@);
    return undef;
}

=item list_all_host_downtime_by_comment

Returns a list of all downtime for the host, grouped by comment and
entry_time

=cut

sub list_all_host_downtime_by_comment {
    my ($self) = @_;

    # Need to check for host or services
    my $sql = "
		SELECT nsd.scheduleddowntime_id
		FROM
			opsview_host_services ohs
		LEFT JOIN nagios_scheduleddowntime nsd ON (nsd.object_id = ohs.service_object_id OR nsd.object_id = ohs.host_object_id)
		WHERE
			ohs.host_object_id = ?
		AND
			nsd.scheduleddowntime_id IS NOT NULL
		GROUP BY nsd.comment_data,nsd.entry_time
		ORDER BY nsd.comment_data,nsd.scheduled_start_time
	";

    my $sth = $self->db_Main->prepare_cached($sql);
    return Runtime::Downtime->sth_to_objects( $sth, [ $self->id ] );
}

=item $self->hostgroup

Returns the Runtime::Hostgroup object which this host is the hostgroup of.

This is highly sneaky as it avoids having to create a new column in the opsview_hosts table. This is a possibly optimisation, but this is
called infrequently

=cut

sub hostgroup {
    my ($self) = @_;

    # Need the lft+1=rgt to get a leaf hostgroup
    my $sql = qq{
SELECT opsview_hostgroups.id
FROM opsview_hostgroups,opsview_hostgroup_hosts
WHERE
 opsview_hostgroups.id = opsview_hostgroup_hosts.hostgroup_id
 AND opsview_hostgroups.lft+1 = opsview_hostgroups.rgt
 AND opsview_hostgroup_hosts.host_object_id = ?
};
    my $sth = $self->db_Main->prepare_cached($sql);

    # Need ->first because returns an iterator
    return Runtime::Hostgroup->sth_to_objects( $sth, [ $self->id ] )->first;
}

=item $obj->can_be_viewed_by($contact_obj)

Check whether or not the given contact has permission to view the object

Returns the object if true, undef if false

=cut

sub can_be_viewed_by {
    my ( $self, $contact_obj ) = @_;

    if ( $contact_obj->has_access("VIEWALL") ) {
        return $self;
    }

    if ( $contact_obj->has_access("VIEWSOME") ) {
        my $dbh = $self->db_Main;
        my $sql = qq{
            SELECT opsview_contact_objects.object_id AS id
            FROM opsview_contact_objects, opsview_host_objects
            WHERE opsview_contact_objects.object_id = opsview_host_objects.object_id
            AND opsview_contact_objects.contactid = ?
            AND opsview_host_objects.object_id = ?
        };
        my $sth = $dbh->prepare($sql);
        my $first =
          Runtime::Host->sth_to_objects( $sth, [ $contact_obj->id, $self->id ] )
          ->first;
        return $first;
    }

    return undef;
}

=item $obj->can_be_changed_by($contact_obj)

Check whether or not the given contact has permisions on the object

Returns the object if true, undef if false

=cut

sub can_be_changed_by {
    my ( $self, $contact_obj ) = @_;

    if ( $contact_obj->has_access("ACTIONALL") ) {
        return $self;
    }

    if ( $contact_obj->has_access("ACTIONSOME") ) {
        my $dbh = $self->db_Main;
        my $sql = qq{
            SELECT DISTINCT host_object_id AS id
            FROM opsview_contact_services ocs
            LEFT JOIN opsview_host_services ohs USING (service_object_id)
            WHERE ocs.contactid = ?
            AND   ohs.host_object_id = ?
        };
        my $sth = $dbh->prepare($sql);
        return Runtime::Host->sth_to_objects( $sth,
            [ $contact_obj->id, $self->id ] )->first;
    }

    return;
}

=item $obj->can_set_downtime_by($contact_obj)

Check whether or not the given contact has permisions to set downtime

Returns true or false

=cut

# This can do with switching to Runtime::Schema::OpsviewHosts
sub can_set_downtime_by {
    my ( $self, $contact_obj ) = @_;

    if ( $contact_obj->has_access("DOWNTIMEALL") ) {
        return $self;
    }

    if ( $contact_obj->has_access("DOWNTIMESOME") ) {
        my $dbh = $self->db_Main;
        my $sql = qq{
            SELECT DISTINCT host_object_id AS id
            FROM opsview_contact_services ocs
            LEFT JOIN opsview_host_services ohs USING (service_object_id)
            WHERE ocs.contactid = ?
            AND   ohs.host_object_id = ?
        };
        my $sth = $dbh->prepare($sql);
        return Runtime::Host->sth_to_objects( $sth,
            [ $contact_obj->id, $self->id ] )->first;
    }

    return;
}

# Use this to test if the runtime host can get to the opsview configuration
sub configuration_host_object {
    my ($self) = @_;
    return Runtime->opsview_schema->resultset("Hosts")
      ->find( $self->opsview_host_id );
}

# Should this be in controller?
sub my_object_uri {
    my ( $self, $c ) = @_;
    $c->uri_for( "/status/service", { host => $self->name } );
}

=item my_type_is

Returns "host"

=cut

sub my_type_is {
    return "host";
}

sub is_handled {
    my $self = shift;
    return (
             $self->current_state != 1
          or $self->problem_has_been_acknowledged == 1
          or $self->scheduled_downtime_depth > 0
    );
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
