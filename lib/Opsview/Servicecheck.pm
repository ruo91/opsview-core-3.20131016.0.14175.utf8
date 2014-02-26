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

package Opsview::Servicecheck;
use base qw/Opsview Opsview::ServiceBase Opsview::KeywordBase/;
use Opsview::Utils;

use strict;
our $VERSION = '$Revision: 2700 $';

__PACKAGE__->table( "servicechecks" );
__PACKAGE__->utf8_columns(qw/description/);
__PACKAGE__->columns( Primary => qw/id/, );

# See Host.pm re: number of columns in Essential
# The Essentials list is based on required parameters for the service_options
# template. This saves pulling any of the Others columns
__PACKAGE__->columns( Essential => qw/name plugin args description/ );
__PACKAGE__->columns(
    Others => qw/checktype servicegroup invertresults notification_options
      notification_period notification_interval check_interval retry_check_interval check_attempts alert_from_failure
      volatile stalking flap_detection_enabled agent uncommitted
      check_period
      check_freshness freshness_type stale_threshold_seconds stale_state stale_text
      markdown_filter attribute event_handler disable_name_change
      /
);

__PACKAGE__->has_a( servicegroup        => "Opsview::Servicegroup" );
__PACKAGE__->has_a( notification_period => "Opsview::Timeperiod" );
__PACKAGE__->has_a( checktype           => "Opsview::Checktype" );
__PACKAGE__->has_a( plugin              => "Opsview::Plugin" );
__PACKAGE__->has_a( agent               => "Opsview::Agent" );
__PACKAGE__->has_many( hosttemplates =>
      [ "Opsview::HosttemplateServicecheck" => "hosttemplateid" ] );
__PACKAGE__->has_many( hosts => [ "Opsview::HostServicecheck" => "hostid" ] );
__PACKAGE__->has_many(
    snmp_actions => [ "Opsview::ServicecheckSnmpaction" => "trapid" ] );
__PACKAGE__->has_many(
    snmp_ignores => [ "Opsview::ServicecheckSnmpignore" => "trapid" ] );
__PACKAGE__->has_many(
    servicecheckhostexceptions => ["Opsview::Servicecheckhostexception"] );
__PACKAGE__->has_many( servicecheckhosttemplateexceptions =>
      ["Opsview::Servicecheckhosttemplateexception"] );
__PACKAGE__->has_many( servicechecktimedoverridehostexceptions =>
      ["Opsview::Servicechecktimedoverridehostexception"] );
__PACKAGE__->has_many( servicechecktimedoverridehosttemplateexceptions =>
      ["Opsview::Servicechecktimedoverridehosttemplateexception"] );
__PACKAGE__->has_many(
    hostserviceeventhandlers => ["Opsview::Hostserviceeventhandler"] );
__PACKAGE__->has_many(
    keywords => [ "Opsview::KeywordServicecheck" => "keywordid" ],
    "servicecheckid"
);
__PACKAGE__->has_many(
    dependencies => [ "Opsview::Servicecheckdependency" => "dependencyid" ],
    "servicecheckid"
);
__PACKAGE__->might_have( snmppolling => "Opsview::ServicecheckSnmppolling" =>
      qw/oid critical_comparison critical_value warning_value warning_comparison check_snmp_threshold_args calculate_rate label/
);
__PACKAGE__->has_a( check_period => "Opsview::Timeperiod" );

# Do not allow ":" in the servicecheck name, as this is reserved for multiple services via host attributes
# this uses the ":" to ensure no clashes at the Nagios service namespace
# There is a problem in that some Nagios macros (like $SERVICEMACRO:host_name:service_description$) use
# the ":", but these are not widely used. Also "," maybe used in membership lists
__PACKAGE__->constrain_column_regexp(
    name => q{/^[\w .\/-]{1,63}$/} => "invalidCharacters", )
  ; # Must compose of alphanumerics and not empty. 63 chars or less
__PACKAGE__->constrain_column_regexp( checktype => q{/^\d+$/} => "required", )
  ; # Is integer

__PACKAGE__->initial_columns(qw/name servicegroup/);

__PACKAGE__->default_search_attributes( { order_by => "name" } );

=head1 NAME

Opsview::Servicecheck - Accessing servicechecks table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview servicechecks information

=head1 METHODS

=over 4

=item all_hosts

Returns an array ref to all the host objects that use this servicecheck, including via a hosttemplate.
Ordered by host name. Duplicates removed

=cut

sub all_hosts {
    my $self = shift;
    my %a = map { $_->id => $_ } $self->hosts;
    foreach my $ht ( $self->hosttemplates ) {
        map { $a{ $_->id } = $_ } $ht->hosts;
    }
    my @a = map { $_->[1] }
      sort { $a->[0] cmp $b->[0] }
      map { [ $a{$_}->name, $a{$_} ] }
      keys %a;
    return \@a;
}

=item count_all_hosts

Returns the number of hosts using this servicecheck, including via a hosttemplate.

=cut

__PACKAGE__->set_sql(
    count_all_hosts => qq{
	SELECT COUNT(DISTINCT(h.name)) 
	FROM hosts h
	LEFT JOIN hostservicechecks hs
	ON hs.hostid=h.id 
	LEFT JOIN hosthosttemplates hht
	ON h.id = hht.hostid
	LEFT JOIN hosttemplateservicechecks hts
	ON hts.hosttemplateid = hht.hosttemplateid
	WHERE
	  hs.servicecheckid = %s OR hts.servicecheckid = %s
	}
);

sub count_all_hosts {
    my $self = shift;
    return $self->sql_count_all_hosts( $self->id, $self->id )->select_val;
}

=item $self->category_and_name

Returns "$category -- $name"

=cut

sub category_and_name {
    my $self = shift;

    # Need to have this ||. Live object caching means that the servicegroup_name may not be saved
    return ( $self->servicegroup_name || $self->servicegroup->name ) . ": "
      . $self->name;
}

=item $self->dependencies_ordered

Returns a list of objects, ordered by usual rules

=cut

__PACKAGE__->set_sql( dependencies_ordered => <<"" );
SELECT __ESSENTIAL(me)__, servicegroups.name as servicegroup_name
FROM __TABLE__ me, servicegroups, servicecheckdependencies dep
WHERE
 dep.servicecheckid = ?
 AND me.id = dep.dependencyid
 AND me.servicegroup = servicegroups.id
ORDER BY
 servicegroups.name, me.name


sub dependencies_ordered {
    my $self = shift;
    my $sth  = $self->sql_dependencies_ordered;
    $sth->execute( $self->id );
    return $self->sth_to_objects($sth);
}

__PACKAGE__->set_sql( joined_servicegroup => <<"" );
SELECT __ESSENTIAL(me)__, servicegroups.name as servicegroup_name
FROM %s
JOIN servicegroups servicegroups
ON (me.servicegroup=servicegroups.id)
WHERE %s
%s
%s


sub joined_servicegroup {
    my $self = shift;
    my $sth  = $self->sql_joined_servicegroup;
    $sth->execute;
    return $self->sth_to_objects($sth);
}

__PACKAGE__->set_sql( joined_servicegroup_Count => <<"" );
SELECT COUNT(*)
FROM %s
WHERE %s


=item $obj->notifications_enabled 

Returns true if is, false if not. Based on other fields

=cut

sub notifications_enabled {
    my $self = shift;
    if   ( $self->notification_options ) { return 1; }
    else                                 { return 0; }
}

=item set_dependencies_to

Sets dependencies to @_. Ignores self

=cut

sub set_dependencies_to {
    my $self = shift;
    Opsview::Servicecheckdependency->search( servicecheckid => $self->id )
      ->delete_all;
    foreach $_ (@_) {
        if ( $_ != $self->id ) {
            $self->add_to_dependencies(
                {
                    servicecheckid => $self->id,
                    dependencyid   => $_
                }
            );
        }
    }
}

=item set_snmp_actions_to

Deletes the foreign key table and adds only the specified list of snmp_actions

=cut

sub set_snmp_actions_to {
    my $self = shift;
    Opsview::ServicecheckSnmpaction->search( servicecheckid => $self->id )
      ->delete_all;
    foreach $_ (@_) {
        $self->add_to_snmp_actions( { trapid => $_ } );
    }
}

=item set_snmp_ignores_to

Deletes the foreign key table and adds only the specified list of snmp_ignores

=cut

sub set_snmp_ignores_to {
    my $self = shift;
    Opsview::ServicecheckSnmpignore->search( servicecheckid => $self->id )
      ->delete_all;
    foreach $_ (@_) {
        $self->add_to_snmp_ignores( { trapid => $_ } );
    }
}

=item $class->find( $servicecheck_name )

Returns an object based on a Nagios servicecheck name. Will check autogenerated names and
return appropriate objects.

=cut

sub find {
    my ( $class, $name ) = @_;
    my $obj;

    if ( $name =~ /^([^:]+?):/ ) {
        $name = $1;
    }
    $obj = $class->search( { name => $name } )->first;
    return $obj;
}

# Used for retrieve_all_by_host
__PACKAGE__->columns( TEMP =>
      qw/ checked exception_checked exception_args timedoverride_checked timedoverride_args timedoverride_timeperiod h_ex_args h_ex_checked h_id h_to_args h_to_checked h_to_timeperiod t_ex_args t_ex_checked t_id t_to_args t_to_checked t_to_timeperiod servicegroup_name remove_servicecheck/,
);

=item $class->retrieve_all_exceptions_by_service ( $svid );

Returns an iterator of all servicechecks for a service including hosts and host templates, with some extra columns: checked, exception_checked, exception_args, timedoverride_checked, timedoverride_args, timedoverride_timeperiod. Used for service exceptions

=cut

#__PACKAGE__->set_sql(all_exceptions_by_service => << "");
sub list_all_exceptions_by_service {
    my $self = shift;
    my $id   = shift;
    my ( $sql, $sth );
    my $dbh = $self->db_Main;

    # Three parts to the SQL:
    #  1. The host exceptions
    #  2. The host template exceptions
    #  3. The removed service checks from the host
    $sql = "
(
SELECT
 me.name, me.plugin, me.category, me.args, me.description,
 hs.hostid as h_id,
 NULL as t_id,
 (sche.host > 0) as h_ex_checked,
 sche.args as h_ex_args,
 (scthe.host > 0) as h_to_checked,
 scthe.args as h_to_args,
 scthe.timeperiod as h_to_timeperiod,
 hseh.event_handler as event_handler,
 NULL as t_ex_checked,
 NULL as t_ex_args,
 NULL as t_to_checked,
 NULL as t_to_args,
 NULL as t_to_timeperiod,
 NULL as remove_servicecheck
FROM servicechecks as me
LEFT JOIN hostservicechecks hs ON (hs.servicecheckid = me.id)
LEFT JOIN servicecheckhostexceptions sche ON (sche.host = hs.hostid AND me.id = sche.servicecheck)
LEFT JOIN servicechecktimedoverridehostexceptions scthe ON (scthe.host = hs.hostid AND me.id = scthe.servicecheck) 
LEFT JOIN hostserviceeventhandlers hseh ON (hseh.hostid = hs.hostid AND me.id = hseh.servicecheckid)
WHERE me.id = ? AND (sche.host > 0 OR scthe.host > 0)
) UNION (
SELECT  
 me.name, me.plugin, me.category, me.args, me.description,
 NULL as h_id,
 htsc.hosttemplateid as t_id,
 NULL as h_ex_checked,
 NULL as h_ex_args,
 NULL as h_to_checked,
 NULL as h_to_args,
 NULL as h_to_timeperiod,
 NULL as event_handler,
 (schte.hosttemplate > 0) as t_ex_checked,
 schte.args as t_ex_args,
 (scthte.hosttemplate > 0) as t_to_checked,
 scthte.args as t_to_args,
 scthte.timeperiod as t_to_timeperiod,
 NULL as remove_servicecheck
FROM servicechecks as me
LEFT JOIN hosttemplateservicechecks htsc ON (htsc.servicecheckid = me.id)
LEFT JOIN servicecheckhosttemplateexceptions schte ON (schte.hosttemplate = htsc.hosttemplateid AND me.id = schte.servicecheck)
LEFT JOIN servicechecktimedoverridehosttemplateexceptions scthte ON (scthte.hosttemplate = htsc.hosttemplateid AND me.id = scthte.servicecheck)
WHERE me.id = ? AND (schte.hosttemplate > 0 OR scthte.hosttemplate > 0)
) UNION (
SELECT  
 me.name, me.plugin, me.category, me.args, me.description,
 hs.hostid as h_id,
 NULL as t_id,
 NULL as h_ex_checked,
 NULL as h_ex_args,
 NULL as h_to_checked,
 NULL as h_to_args,
 NULL as h_to_timeperiod,
 NULL as event_handler,
 NULL as t_ex_checked,
 NULL as t_ex_args,
 NULL as t_to_checked,
 NULL as t_to_args,
 NULL as t_to_timeperiod,
 1    as remove_servicecheck
FROM servicechecks as me
LEFT JOIN hostservicechecks hs ON (hs.servicecheckid = me.id)
WHERE me.id = ? AND hs.remove_servicecheck = 1
)
ORDER BY h_id,t_id
";
    $sth = $dbh->prepare_cached($sql);
    $sth->execute( $id, $id, $id );

    return $sth;
}

sub retrieve_all_exceptions_by_service {
    my ( $class, $svid ) = @_;
    my $sth = $class->list_all_exceptions_by_service($svid);
    my @results;

    # Query returns 1 row per host and host template. However, could have a timed override
    # and a normal override in same host/host template. We use this routine to
    # create extra rows in the @result
    while ( my $row = $sth->fetchrow_hashref ) {

        # Create the basic hash, which will be copied before pushing onto @result
        my $h = {};
        if ( $row->{h_id} ) {
            $h->{h_id} = Opsview::Host->construct( { id => $row->{h_id} } );
        }
        if ( $row->{t_id} ) {
            $h->{t_id} =
              Opsview::Hosttemplate->construct( { id => $row->{t_id} } );
        }
        if ( $row->{h_to_timeperiod} ) {
            $h->{h_to_timeperiod} =
              Opsview::Timeperiod->construct( { id => $row->{h_to_timeperiod} }
              );
        }
        if ( $row->{t_to_timeperiod} ) {
            $h->{t_to_timeperiod} =
              Opsview::Timeperiod->construct( { id => $row->{t_to_timeperiod} }
              );
        }

        if ( $row->{h_ex_checked} ) {
            my $newrow = {%$h};
            $newrow->{h_ex_checked} = 1;
            $newrow->{h_ex_args}    = $row->{h_ex_args};
            push @results, $newrow;
        }
        if ( $row->{t_ex_checked} ) {
            my $newrow = {%$h};
            $newrow->{t_ex_checked} = 1;
            $newrow->{t_ex_args}    = $row->{t_ex_args};
            push @results, $newrow;
        }
        if ( $row->{h_to_checked} ) {
            my $newrow = {%$h};
            $newrow->{h_to_checked} = 1;
            $newrow->{h_to_args}    = $row->{h_to_args};
            push @results, $newrow;
        }
        if ( $row->{t_to_checked} ) {
            my $newrow = {%$h};
            $newrow->{t_to_checked} = 1;
            $newrow->{t_to_args}    = $row->{t_to_args};
            push @results, $newrow;
        }
        if ( $row->{remove_servicecheck} ) {
            my $newrow = {%$h};
            $newrow->{remove_servicecheck} = 1;
            push @results, $newrow;
        }
    }

    return @results;
}

=item $class->count_all_exceptions_by_service ( $svid );

Returns a count of the number of exceptions for a servicecheck, from both hosts and host templates. Used for service exceptions.

=cut

# designed for code reuse rather than speed
sub count_all_exceptions_by_service {
    my ( $class, $svid ) = @_;
    my @array = $class->retrieve_all_exceptions_by_service($svid);
    return scalar(@array);
}

=item $self->retrieve_plugins_by_agent

Returns an arrayref of Opsview::Plugin objects that this servicecheck can use, based on agent

=cut

sub retrieve_plugins_by_agent {
    my $self = shift;
    Opsview::Plugin->search_by_agent( $self->agent );
}

sub fetchall {
    my $class = shift;
    my $dbh   = $class->db_Main;
    my $sth   = $dbh->prepare_cached( "SELECT * FROM servicechecks" );
    $sth->execute;
    return map { $class->construct($_) } $sth->fetchall_hash;
}

=item Opsview::Servicecheck->resolved_dependencies( $monitoringserver )

Returns an arrayref with one row for each dependency that needs to be setup. Of format: 

  [
    { host => { name => hostname },
      servicecheck => { name => servicecheckname, attribute => attribute },
      dependency => { name => dependencyservicecheckname },
    },
    ...
  ]

If monitoringserver is master, return everything. If not, only return hosts that are on that monitoringserver

=cut

sub resolved_dependencies {
    my ( $class, $ms ) = @_;
    my $dbh = $class->db_Main;

    # Need a staging area because there may be duplicated (hostid, servicecheckid)
    # Remove all hosts that belong to a de-activated monitoringserver
    $dbh->do(
        "CREATE TEMPORARY TABLE temp_host_services_staging (hostid int, servicecheckid int) ENGINE=MyISAM"
    );
    $dbh->do(
        qq{
INSERT INTO temp_host_services_staging 
SELECT hsc.hostid, hsc.servicecheckid
FROM hostservicechecks hsc, hosts h, monitoringservers ms
WHERE hsc.hostid = h.id
AND h.monitored_by = ms.id
AND ms.activated = 1
AND hsc.remove_servicecheck = 0
}
    );

    # This query needs to take into consideration whether a service check has been excluded from templates at the host level (remove_servicecheck)
    $dbh->do(
        qq{
INSERT INTO temp_host_services_staging 
SELECT hht.hostid, htsc.servicecheckid
FROM hosthosttemplates hht 
JOIN hosttemplateservicechecks htsc 
 ON hht.hosttemplateid = htsc.hosttemplateid 
JOIN hosts h 
 ON hht.hostid = h.id 
JOIN monitoringservers ms
 ON h.monitored_by = ms.id 
LEFT JOIN hostservicechecks hsc 
 ON hsc.hostid = h.id AND hsc.servicecheckid = htsc.servicecheckid 
WHERE ms.activated = 1 AND (hsc.remove_servicecheck = 0 OR hsc.remove_servicecheck IS NULL)
}
    );

    # Now remove duplicates. Not sure if this is the right SQL, but works in 4.1
    # We filter this by only services that are dependents
    $dbh->do(
        "CREATE TEMPORARY TABLE temp_host_services (hostid int, servicecheckid int)"
    );
    $dbh->do(
        "INSERT INTO temp_host_services
SELECT DISTINCT(temp.hostid), temp.servicecheckid 
FROM temp_host_services_staging temp, servicecheckdependencies scdep 
WHERE temp.servicecheckid=scdep.dependencyid"
    );

    # Do the same thing, but this is for the services that have dependencies
    $dbh->do(
        'CREATE TEMPORARY TABLE temp_host_services2 (hostid int, servicecheckid int, attribute int, servicecheckname VARCHAR(64))'
    );
    $dbh->do(
        'INSERT INTO temp_host_services2 
SELECT DISTINCT(temp.hostid), temp.servicecheckid, sc.attribute, sc.name
FROM temp_host_services_staging temp, servicechecks sc, servicecheckdependencies scdep 
WHERE temp.servicecheckid=sc.id AND sc.id=scdep.servicecheckid'
    );

    $dbh->do( "DROP TEMPORARY TABLE temp_host_services_staging" );

    my $sql = <<"";
SELECT
h.name as host_name, servicechecks.name as dependency_name, hs2.attribute as servicecheck_attribute, hs2.servicecheckname as servicecheck_name
FROM
temp_host_services hs,
temp_host_services2 hs2,
servicecheckdependencies scdep,
hosts h,
servicechecks
WHERE
hs2.servicecheckid = scdep.servicecheckid
and hs2.hostid = hs.hostid
and hs.servicecheckid = scdep.dependencyid
and h.id = hs2.hostid
and scdep.dependencyid = servicechecks.id
and servicechecks.attribute IS NULL

    my $sth;
    my @bind;
    unless ( $ms->is_master ) {
        $sql .= " and h.monitored_by = ?";
        push @bind, $ms->id;
    }

    # The ORDER BY clause is for testing, but it is pretty fast so can leave it in
    $sql .= " ORDER BY hs2.servicecheckid, hs2.hostid";
    $sth = $dbh->prepare_cached($sql);
    $sth->execute(@bind);

    my @results;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $h = {};
        $h->{host} = { name => $row->{host_name} };
        $h->{servicecheck} = {
            name      => $row->{servicecheck_name},
            attribute => $row->{servicecheck_attribute},
        };
        $h->{dependency} = { name => $row->{dependency_name} };
        push @results, $h;
    }

    $dbh->do( "DROP TEMPORARY TABLE temp_host_services" );
    $dbh->do( "DROP TEMPORARY TABLE temp_host_services2" );

    return \@results;
}

=item my_type_is

Returns "service check"

=cut

sub my_type_is {
    return "service check";
}
sub my_web_type {"servicecheck"}

=item $class->list_servicegroups( { search stuff } )

Returns a list of hashes of form:
{
  servicegroup_id => servicegroup.id,
  servicegroup_name => servicegroup.name,
  servicegroup => servicegroup object,
  services => # of services
  servicechecked => # of services checked for this host/hosttemplate
}

=cut

sub list_servicegroups {
    my ( $class, $args ) = @_;
    my $dbh = $class->db_Main;
    my $joined_table;
    my $column_name;
    my $id;
    if ( $args->{hostid} ) {
        $joined_table = "hostservicechecks";
        $column_name  = "hostid";
        $id           = $args->{hostid};
    }
    else {
        $joined_table = "hosttemplateservicechecks";
        $column_name  = "hosttemplateid";
        $id           = $args->{hosttemplateid};
    }
    my $sth = $dbh->prepare_cached(
        qq{
SELECT 
 servicegroups.id as servicegroup_id,
 servicegroups.name as servicegroup_name, 
 COUNT(*) as services, 
 COUNT(joined_table.servicecheckid) as services_checked
FROM servicechecks 
LEFT JOIN $joined_table joined_table 
ON (joined_table.$column_name = ? and joined_table.servicecheckid = servicechecks.id ) 
JOIN servicegroups 
ON (servicegroups.id = servicechecks.servicegroup) 
GROUP BY servicegroup_name
}
    );
    $sth->execute($id);
    my @results;
    my $hash;
    while ( my $hash = $sth->fetchrow_hashref ) {
        $hash->{servicegroup} =
          Opsview::Servicegroup->construct( { id => $hash->{servicegroup_id} }
          );
        push @results, $hash;
    }
    return \@results;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
