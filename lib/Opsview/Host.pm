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

package Opsview::__::Host;
use strict;
use Class::Accessor::Fast;

use base qw/Opsview Opsview::KeywordBase Opsview::HostBase/;

__PACKAGE__->mk_classdata( opsview_keyword_class => "Opsview" );
__PACKAGE__->mk_classdata( opsview_keyword_col   => "hostid" );

my $my_cache = {};
sub my_cache { return $my_cache }

__PACKAGE__->table( "hosts" );

__PACKAGE__->columns( Primary => qw/id/, );

# Need to balance the number of columns in Essential and Others
# Better to have fewer in Essential for web pages, but possibly better
# for batch jobs (eg nagconfgen) to have more.
# As web pages are accessed more frequently, err on the side of web pages
__PACKAGE__->columns( Essential => qw/name ip alias/ );

# TODO: snmpv3 attributes should be moved into a might_have relationship
__PACKAGE__->columns(
    Others => qw/hostgroup http_admin_url http_admin_port icon monitored_by
      notification_interval
      notification_options notification_period check_command
      check_period check_interval retry_check_interval check_attempts
      enable_snmp snmp_version snmp_port snmp_community
      snmpv3_username snmpv3_authpassword snmpv3_authprotocol snmpv3_privprotocol snmpv3_privpassword
      other_addresses snmptrap_tracing
      flap_detection_enabled
      use_nmis nmis_node_type
      use_rancid rancid_vendor rancid_username rancid_password rancid_connection_type
      rancid_autoenable use_mrtg
      uncommitted
      event_handler
      /,
);
__PACKAGE__->columns( TEMP => qw/primaryclusternode secondaryclusternode/, );

package Opsview::Host;
use base 'Opsview::__::Host';
use Carp;

__PACKAGE__->utf8_columns( qw(name ip alias) );

sub notification_interval {
    my $self = shift;
    if (@_) {
        $self->SUPER::notification_interval(@_);
    }
    else {
        $_ = $self->SUPER::notification_interval;
        defined $_ ? $_ : 60;
    }
}

#__PACKAGE__->columns(Stringify => qw/name/);

__PACKAGE__->has_many(
    parents => [ "Opsview::Parent" => 'parentid' ],
    "hostid"
);
__PACKAGE__->has_many(
    children => [ "Opsview::Parent" => 'hostid' ],
    "parentid"
);
__PACKAGE__->has_many(
    servicechecks => [ "Opsview::HostServicecheck" => 'servicecheckid' ],
    "hostid"
);
__PACKAGE__->has_many(
    servicecheckexceptions => ["Opsview::Servicecheckhostexception"] );
__PACKAGE__->has_many( servicechecktimedoverrideexceptions =>
      ["Opsview::Servicechecktimedoverridehostexception"] );
__PACKAGE__->has_many(
    hostserviceeventhandlers => ["Opsview::Hostserviceeventhandler"] );
__PACKAGE__->has_many(
    keywords => [ "Opsview::KeywordHost" => "keywordid" ],
    "hostid"
);
__PACKAGE__->has_many(
    snmpinterfaces => ["Opsview::HostSnmpinterface"],
    { order_by => "interfacename" }
);
__PACKAGE__->has_many(
    snmpwalkcaches => ["Opsview::Snmpwalkcache"],
    "hostid"
);

__PACKAGE__->has_many_fields(
    [
        qw[
          parents servicechecks
          servicecheckexceptions servicechecktimedoverrideexceptions keywords
          snmpinterfaces hosttemplates
          ]
    ]
);
__PACKAGE__->ignore_clone_fields(
    [
        qw[
          servicecheckexceptions servicechecktimedoverrideexceptions
          snmpinterfaces
          snmptrap_tracing
          ]
    ]
);

__PACKAGE__->has_a( hostgroup           => "Opsview::Hostgroup" );
__PACKAGE__->has_a( icon                => "Opsview::Icon" );
__PACKAGE__->has_a( notification_period => "Opsview::Timeperiod" );
__PACKAGE__->has_a( check_period        => "Opsview::Timeperiod" );
__PACKAGE__->has_a( check_command       => "Opsview::HostCheckCommand" );
__PACKAGE__->has_a( rancid_vendor       => "Opsview::Rancidvendor" );
__PACKAGE__->has_many(
    hosttemplates => [ "Opsview::HostHosttemplate" => "hosttemplateid" ],
    "hostid", { order_by => "priority" }
);

sub hosttemplates_arrayref {
    my @a = shift->hosttemplates;
    return [@a];
}

__PACKAGE__->has_a( monitored_by => "Opsview::Monitoringserver" );

__PACKAGE__->might_have( info => "Opsview::Hostinfo" => qw/ information / );

# Do not allow ":" in the name, nor "," - used in other parts of Nagios configuration
# like on-demand macros and membership
__PACKAGE__->constrain_column_regexp(
    name => q{/^[\w\.-]{1,63}$/} => "invalidCharacters", )
  ; # Must compose of alphanumerics and not empty. Maximum 63 chars
__PACKAGE__->constrain_column_regexp(
    ip => q{/^[^\[\]`~!\$%^&*|'"<>?,()= ]{1,254}$/} => "invalidCharacters", )
  ; # Must compose of alphanumerics and not empty. Maximum 254 chars

# Don't set these constraints yet - causes problems with opsview-web/t/601-api.t
#__PACKAGE__->constrain_column(snmp_version => qr/^(1|2c|3)$/);
#__PACKAGE__->constrain_column(snmpv3_authprotocol => qr/^(md5|sha)$/ );
#__PACKAGE__->constrain_column(snmpv3_privprotocol => qr/^(des|aes|aes128)$/ );

__PACKAGE__->constrain_column_regexp(
    other_addresses => q{/^ *(([\w\.:-]+)?( *, *)?)* *$/} =>
      "invalidCharactersOnlyAlphanumericsOrPeriodDash" );
__PACKAGE__->constrain_column_regexp(
    snmpv3_authpassword => '/^$|^.{8,}$/' => "requireEightCharacters" );
__PACKAGE__->constrain_column_regexp(
    snmpv3_privpassword => '/^$|^.{8,}$/' => "requireEightCharacters" );

# Have to constrain these characters because cannot quote them correctly in .cloginrc
__PACKAGE__->constrain_column_regexp(
    rancid_password => '/^[^{}]*$/' => "invalidCurlyBrackets" );

# Must compose of alphanumerics, $'s and spaces (to cater for MACROS args)
# or empty
__PACKAGE__->constrain_column_regexp(
    event_handler => q{/^(?:[\w\.\$ -]+)?$/} =>
      "invalidCharactersOnlyAlphanumericsOrPeriodDashSpaceDollar" );

__PACKAGE__->initial_columns(qw/name ip hostgroup icon/);

__PACKAGE__->default_search_attributes( { order_by => "name" } );

__PACKAGE__->add_trigger( after_create => \&set_monitored_by_create );

sub set_monitored_by_create {
    my $self = shift;
    my ($ms) = Opsview::Monitoringserver->search( role => "Master" );
    return unless $ms; # Exit if no monitoringserver exists yet
    $self->monitored_by($ms);
    $self->update;
}

__PACKAGE__->add_constraint( 'hostgroup_must_be_leaf',
    hostgroup => \&check_hostgroup_must_be_leaf );

sub check_hostgroup_must_be_leaf {
    my ( $value, $self ) = @_;
    my $hg = $value;
    unless ( ref $value ) {
        $hg = Opsview::Hostgroup->retrieve($value) or return 0;
    }
    return 1 if ( $hg->is_leaf );
    return 0;
}

=head1 NAME

Opsview::Host - Accessing hosts table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview host information

=head1 METHODS

=over 4

=item set_hosttemplates_to

Deletes the foreign key table and adds only the specified list of hosttemplates

=cut

sub set_hosttemplates_to {
    my $self     = shift;
    my $priority = 1;
    Opsview::HostHosttemplate->search( hostid => $self->id )->delete_all;
    foreach $_ (@_) {
        $self->add_to_hosttemplates(
            {
                hostid         => $self->id,
                hosttemplateid => $_,
                priority       => $priority
            }
        );
        $priority++;
    }
}

=item set_parents_to

Deletes the foreign key table and adds only the specified list of parents. Deletes itself if attempts to set itself as parent

=cut

sub set_parents_to {
    my $self = shift;
    Opsview::Parent->search( hostid => $self->id )->delete_all;
    foreach $_ (@_) {
        if ( $_ != $self->id ) {
            $self->add_to_parents(
                {
                    hostid   => $self->id,
                    parentid => $_
                }
            );
        }
    }
}

=item set_servicechecks_to

Deletes the foreign key table and adds only the specified list of servicechecks.

The id coming in could be prefixed with "remove-", which means to set the remove_servicecheck flag in the table

=cut

sub set_servicechecks_to {
    my $self = shift;
    Opsview::HostServicecheck->search( hostid => $self->id )->delete_all;
    foreach my $scid (@_) {
        my %extra = ();

        # Not sure why, but $scid doesn't like being set within the if below. This fails test 50hosts.t
        my $use_scid = $scid;
        if ( $scid =~ /^remove-(\d+)$/ ) {
            $use_scid = $1;
            $extra{remove_servicecheck} = 1;
        }
        $self->add_to_servicechecks(
            {
                hostid         => $self->id,
                servicecheckid => $use_scid,
                %extra
            }
        );
    }
}

=item set_snmpinterfaces_on_off( $all_arrayref, $on_arrayref, $warning_ref, $critical_ref, $indexid )

Sets all interfaces to be from $all, and only activates the ones in $on. The warning and critical arrays should be the same
length as $all and will be used respectively.

=cut

sub set_snmpinterfaces_on_off {
    my $self = shift;
    my ( $all, $on, $warning, $critical, $indexid ) = @_;
    my %active;
    map { $active{$_}++ } @$on;

    foreach $_ (@$all) {
        my $obj = Opsview::HostSnmpinterface->search(
            {
                hostid        => $self->id,
                interfacename => $_,
            }
        )->first();
        if ($obj) {
            $obj->warning( shift @$warning );
            $obj->critical( shift @$critical );
            $obj->indexid( shift @$indexid );
        }
        else {
            my $args = {
                hostid        => $self->id,
                interfacename => $_,
                warning       => shift @$warning,
                critical      => shift @$critical,
                indexid       => shift @$indexid,
            };
            $obj = $self->add_to_snmpinterfaces($args);
        }
        $obj->active( $active{$_} || 0 );
        $obj->update;
    }

    # delete any interface not provided in the list
    my $all_names = {};
    map { $all_names->{$_}++ } @$all;
    foreach
      my $iface ( Opsview::HostSnmpinterface->search( hostid => $self->id ) )
    {
        my $name = $iface->interfacename;
        unless ( exists $all_names->{$name} ) {
            $iface->delete;
        }
    }
}

=item list_keywords

Returns a scalar with the list of keywords, separated by $1 (default comma)

=cut

sub list_keywords {
    my ( $self, $sep ) = @_;
    $sep ||= ",";
    return join( $sep, $self->keywords );
}

=item count_servicechecks

Returns the number of servicechecks for this host

=cut

*weight = \&count_servicechecks; # Used for Set::Cluster

# Using prepare_cached seems to cause problems when running nagconfgen. Reinvestigate later
# though it is probably not a huge time saver
sub count_servicechecks {
    my $self     = shift;
    my $dbh      = $self->db_Main;
    my $count_ht = $dbh->selectrow_array( "
SELECT COUNT(DISTINCT(htsc.servicecheckid)) 
FROM hosthosttemplates hht, 
 hosttemplateservicechecks htsc 
WHERE hht.hostid = " . $self->id . "
AND hht.hosttemplateid = htsc.hosttemplateid
" );
    my $count_custom = $dbh->selectrow_array( "
SELECT COUNT(*) FROM hostservicechecks
WHERE hostid = " . $self->id );
    return $count_ht + $count_custom;
}

=item monitoringserver

Returns an Opsview::Monitoringserver object if this server is used as a monitoring
server. Otherwise null. Very expensive routine - see monitoringserver_precache

=cut

sub monitoringserver {
    return Opsview::Monitoringserver->search_for_host(shift);
}

=item monitoringserver_cached

Caches the monitoringserver call. Do not use in very long running processes, but can
use for nagconfgen

=cut

sub monitoringserver_cached {
    my $self  = shift;
    my $cache = $self->my_cache;
    unless ( exists $cache->{monitoringservers} ) {
        foreach my $ms ( Opsview::Monitoringserver->retrieve_all ) {
            foreach my $h ( $ms->hosts ) {
                $cache->{monitoringservers}->{ $h->id } = $ms;
            }
        }
    }
    return $cache->{monitoringservers}->{ $self->id };
}

=item services_by_monitoringserver_lookup

Returns a hash of form: $hash->{$ms->id}->{$host->id} = # of services

=cut

# This could be speeded up with a cleverer SQL
sub services_by_monitoringserver_lookup {
    my $class = shift;
    my $hash  = {};
    foreach my $ms ( Opsview::Monitoringserver->retrieve_all ) {
        foreach my $h ( $ms->monitors ) {
            my $num_of_services = $h->count_servicechecks;
            $hash->{ $ms->id }->{ $h->id } = $num_of_services;
        }
    }
    return $hash;
}

=item is_a_monitoringserver_lookup

Returns a has of form: $hash->{$hostid} = $ms

=cut

sub is_a_monitoringserver_lookup {
    my $class = shift;
    my $hash  = {};
    foreach my $ms ( Opsview::Monitoringserver->retrieve_all ) {
        foreach my $h ( $ms->hosts ) {
            $hash->{ $h->id } = $ms;
        }
    }
    return $hash;
}

=item $self->hostip( $address )

Uses $address if specified, otherwise $self->ip.

Returns an array ref of ip addresses for this host, as resolved by gethostbyname(3).  Returns
an empty array ref if unable to resolve it correctly.

=cut

sub hostip {
    my ( $self, $address ) = @_;
    use Net::hostent;
    use Socket;
    $address = $self->ip unless defined $address;

    if ( $address =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
        return [$address];
    }

    $_ = Net::hostent::gethost($address);
    unless ($_) {
        return [];
    }
    my @addresses = ();
    for my $addr ( @{ $_->addr_list } ) {
        push @addresses, inet_ntoa($addr);
    }
    return \@addresses;
}

=item $self->is_active

Host is considered active if the monitored_by monitoringserver is activated. If no monitoring server, then is
always active

=cut

sub is_active {
    my $self = shift;
    return 0
      if ( $self->monitoringserver && !$self->monitoringserver->is_activated );
    if ( $self->monitored_by ) {
        return $self->monitored_by->is_activated;
    }
    else {
        return 1;
    }
}

=item $self->is_passive

Host is considered passive the monitored_by monitoringserver is activated. If no monitoring server, then is
always active

=cut

sub is_passive {
    my $self = shift;
    return 0
      if ( $self->monitoringserver && !$self->monitoringserver->is_passive );
    if ( $self->monitored_by ) {
        return $self->monitored_by->is_passive;
    }
    else {
        return 0;
    }
}

=item $self->hostgroup_1_to_9

Returns back a list ref of names of the hostgroups that this object belongs to,
based on Hostgroup Hierarchy

=cut

my $temporary_hostgroup_table = 0;

sub hostgroup_1_to_9 {
    my $self = shift;

    # optimization using materialized path
    my @path = split( /,/, $self->hostgroup->matpath );
    return \@path;
}

=item Opsview::Hosts->search_active_hosts

Returns only hosts which are active, according to monitoringserver settings

=cut

__PACKAGE__->set_sql(
    active_hosts => qq{
  SELECT hosts.id 
  FROM hosts, monitoringservers 
  WHERE hosts.monitored_by=monitoringservers.id 
  AND monitoringservers.activated = 1
  ORDER BY hosts.name
  }
);

=item $class->search_snmp_hosts_by_name( $string )

Returns list of hosts where name is like $string. Used for autocompletion

=cut

# Need != "" as sometimes is not null
__PACKAGE__->set_sql(
    snmp_hosts_by_name => qq{
  SELECT __ESSENTIAL__
  FROM __TABLE__
  WHERE ((snmp_community IS NOT NULL AND snmp_community != "")
  OR (snmpv3_authpassword IS NOT NULL AND snmpv3_authpassword != ""))
  AND name LIKE ?
  }
);

=item $class->retrieve_non_monitoringserver_hosts($ms)

Returns an array ref with the list of hosts that are not currently monitoringservers.
If $ms is specified, will add those servers to list

=cut

__PACKAGE__->set_sql( non_monitoringserver_hosts => <<"" );
SELECT __ESSENTIAL(me)__
FROM __TABLE__ me
LEFT JOIN monitoringservers ms
ON (me.id = ms.host)
LEFT JOIN monitoringclusternodes mcn
ON (me.id = mcn.host)
WHERE (ms.host IS NULL
AND mcn.host IS NULL)
ORDER BY me.name

__PACKAGE__->set_sql( non_monitoringserver_hosts_with_this => <<"" );
SELECT __ESSENTIAL(me)__
FROM __TABLE__ me
LEFT JOIN monitoringservers ms
ON (me.id = ms.host)
LEFT JOIN monitoringclusternodes mcn
ON (me.id = mcn.host)
WHERE (ms.host IS NULL
AND mcn.host IS NULL)
OR (ms.id = ?
OR mcn.monitoringcluster = ?)
ORDER BY me.name


sub retrieve_non_monitoringserver_hosts {
    my ( $class, $ms ) = @_;
    my $sth;
    if ($ms) {
        $sth = $class->sql_non_monitoringserver_hosts_with_this;
        $sth->execute( $ms->id, $ms->id );
    }
    else {
        $sth = $class->sql_non_monitoringserver_hosts;
        $sth->execute;
    }
    my @objects = $class->sth_to_objects($sth);
    return \@objects;
}

=item $self->find_parents

Returns the active parents for this host as an array ref. The first time run of this creates a cache image
but never expires it - don't use this function in long running processes

=cut

sub find_parents {
    my $self = shift;
    if ( !defined $self->my_cache->{parents} ) {
        my $dbh = $self->db_Main;
        my $sth = $dbh->prepare(
            qq{
SELECT h.id, p.parentid 
FROM monitoringservers ms, monitoringservers ms2, hosts h2, hosts h, parents p
WHERE h.id = p.hostid
AND h.monitored_by=ms.id 
AND ms.activated = 1 
AND p.parentid = h2.id 
AND h2.monitored_by=ms2.id 
AND ms2.activated = 1 
ORDER BY h.id,p.parentid
}
        );
        $sth->execute;
        my $last  = 0;
        my $hosts = [];
        while ( my ( $id, $parent_id ) = $sth->fetchrow_array ) {
            if ( $last != $id ) {
                if ($last) {
                    $self->my_cache->{parents}->{$last} = $hosts;
                }
                $last  = $id;
                $hosts = [];
            }
            push @$hosts, $self->construct( { id => $parent_id } )
              if $parent_id;
        }
        $self->my_cache->{parents}->{$last} = $hosts;
    }
    return @{ $self->my_cache->{parents}->{ $self->id } || [] };
}

=item search_ordered_nodes($monitoringclusterid)

Returns the list of hosts, ordered by name of host, which is used in the specified monitoring cluster

=cut

__PACKAGE__->set_sql(
    ordered_nodes => qq{
        SELECT hosts.id
        FROM hosts, monitoringservers, monitoringclusternodes
        WHERE monitoringservers.id = monitoringclusternodes.monitoringcluster
        AND monitoringclusternodes.host = hosts.id
        AND monitoringservers.id = ?
	ORDER BY hosts.name
        }
);

=item $self->contactgroups

Returns a list of contactgroups that this host belongs to. This is currently only "hostgroup".$self->hostgroup->id

=cut

sub contactgroups {
    my $self = shift;
    return ( $self->hostgroup->typeid );
}

=item $self->list_resolved_services

Returns a $sth handle, giving following information in a hashref:
 id (servicecheck)
 name (servicecheck)
 servicegroup_name (servicecheck)
 description (servicecheck)
 args (servicecheck)
 exception_args ( this also determines if an exception exists)
 timedoverride_args ( this also determines if a timed override exists)
 timedoverride_timeperiod (timeperiods)
 remove_servicecheck (determines if the servicecheck is removed from later templates)
 hosttemplate_name (or "Custom")
 hosttemplate_id (or 0 for custom)
 priority (of hosttemplate for this host)

Duplicate servicechecks will be returned but the first will always be of the highest priority. 
Whatever is receiving results needs to be aware of this. No objects created

=cut

sub list_resolved_services {
    my ($self) = shift;
    my ( $sql, $sth );
    my $dbh = $self->db_Main;

    $sql = "
(
SELECT
 sc.id as id,
 sc.name as name,
 servicegroups.name as servicegroup_name,
 sc.description as description,
 sc.args as args,
 sche.args as exception_args,
 scthe.args as timedoverride_args,
 tp.name as timedoverride_timeperiod,
 hs.remove_servicecheck as remove_servicecheck,
 'Custom' as hosttemplate_name,
 0 as hosttemplate_id,
 0 as priority,
 hseh.event_handler as event_handler,
 sc.attribute
FROM
 (servicechecks sc,
 hostservicechecks hs)
LEFT JOIN
 servicecheckhostexceptions sche
ON
 (sche.host = hs.hostid and sc.id = sche.servicecheck)
LEFT JOIN
 servicechecktimedoverridehostexceptions scthe
ON
 (scthe.host = hs.hostid and sc.id = scthe.servicecheck)
LEFT JOIN
 timeperiods tp
ON
  (scthe.timeperiod = tp.id)
LEFT JOIN
 hostserviceeventhandlers hseh
ON
 (hs.hostid = hseh.hostid and hs.servicecheckid = hseh.servicecheckid)
JOIN servicegroups
ON sc.servicegroup = servicegroups.id
WHERE
 hs.hostid = ?
 and hs.servicecheckid = sc.id
)
UNION
(
SELECT
 sc.id,
 sc.name,
 servicegroups.name,
 sc.description,
 sc.args,
 schte.args,
 scthte.args AS timedoverride_args,
 tp.name as timedoverride_timeperiod,
 0 as remove_servicecheck,
 ht.name,
 ht.id,
 hht.priority,
 NULL as event_handler,
 sc.attribute
FROM
 ( servicechecks sc,
 hosthosttemplates hht,
 hosttemplates ht,
 hosttemplateservicechecks htsc )
LEFT JOIN
 servicecheckhosttemplateexceptions schte
ON
 (schte.hosttemplate = htsc.hosttemplateid and sc.id=schte.servicecheck)
LEFT JOIN
 servicechecktimedoverridehosttemplateexceptions scthte
ON
 (scthte.hosttemplate = htsc.hosttemplateid and sc.id=scthte.servicecheck)
LEFT JOIN
 timeperiods tp
ON
  (scthte.timeperiod = tp.id)
JOIN servicegroups
ON sc.servicegroup = servicegroups.id
WHERE
 hht.hostid = ?
 and hht.hosttemplateid = ht.id
 and ht.id = htsc.hosttemplateid
 and htsc.servicecheckid = sc.id
)
ORDER BY
 servicegroup_name, name, priority
";
    $sth = $dbh->prepare_cached($sql);
    $sth->execute( $self->id, $self->id );

    return $sth;
}

=list $self->resolved_servicechecks

As $self->list_resolved_services, but will return an array of objects in the result set. 
Use this in preference to list_resolved_services. Of form:

  [ { servicecheck => Opsview::Servicecheck,
	args => exception arg (if exists) else servicecheck->args,
	exception => 0|1,
	timedoverride => 0|1,
	hosttemplate => Opsview::Hosttemplate (or 0 if Custom),
	hosttemplate_name => Opsview::Hosttemplate->name or "Custom",
	priority => of hosttemplate for this host
	}, ... ]
	
=cut

sub resolved_servicechecks {
    my $self = shift;
    my $sth  = $self->list_resolved_services;
    my @results;
    my $scid = 0;
    my $removed_templates;
    while ( my $row = $sth->fetchrow_hashref ) {

        # Magic! Removes other occurances of the servicecheck in other templates
        if ( $scid == $row->{id} ) {

            # Save the host template names that get removed, for UI reporting purposes
            if ($removed_templates) {
                push @$removed_templates,
                  {
                    id           => $row->{hosttemplate_id},
                    hosttemplate => Opsview::Hosttemplate->construct(
                        { id => $row->{hosttemplate_id} }
                    ),
                    hosttemplate_name => $row->{hosttemplate_name},
                  };
            }
            next;
        }

        $scid = $row->{id};

        my $h = {};
        $h->{servicecheck} =
          Opsview::Servicecheck->construct( { id => $scid } );
        if ( defined $row->{exception_args} ) {
            $h->{args}      = $row->{exception_args};
            $h->{exception} = 1;
        }
        else {
            $h->{args}      = $row->{args};
            $h->{exception} = 0;
        }
        if (   defined( $row->{timedoverride_args} )
            || defined( $row->{timedoverride_timeperiod} ) )
        {
            $h->{timedoverride_args}       = $row->{timedoverride_args};
            $h->{timedoverride_timeperiod} = $row->{timedoverride_timeperiod};
            $h->{timedoverride}            = 1;
        }
        else {
            $h->{timedoverride} = 0;
        }
        if ( $row->{hosttemplate_id} ) {
            $h->{hosttemplate} = Opsview::Hosttemplate->construct(
                { id => $row->{hosttemplate_id} }
            );
        }
        else {
            $h->{hosttemplate} = 0;
        }
        $h->{hosttemplate_name}   = $row->{hosttemplate_name};
        $h->{priority}            = $row->{priority};
        $h->{event_handler}       = $row->{event_handler};
        $h->{servicegroup_name}   = $row->{servicegroup_name};
        $h->{remove_servicecheck} = $row->{remove_servicecheck};
        $h->{attribute}           = $row->{attribute};

        if ( $h->{remove_servicecheck} ) {
            $removed_templates = $h->{removed_templates} = [];
        }
        else {
            $removed_templates = 0;
        }

        push @results, $h;
    }
    return \@results;
}

=list $host->list_managementurls

Returns an array ref of all the management urls for this host, based on the host templates.
Will also resolve any host macro definitions

=cut

sub list_managementurls {
    my ($self) = @_;
    my @results = ();
    my %seen;
    foreach my $ht ( $self->hosttemplates ) {
        foreach my $m ( $ht->managementurls ) {
            if ( !$seen{ $m->name } ) {
                push @results,
                  {
                    name          => $m->name,
                    url           => $self->expand_link_macros( $m->url ),
                    host_template => $ht->name,
                  };
            }
            $seen{ $m->name } = 1;
        }
    }
    return \@results;
}

sub fetchall {
    my $class = shift;
    my $dbh   = $class->db_Main;
    my $sth   = $dbh->prepare_cached( "SELECT * FROM hosts" );
    $sth->execute;
    return map { $class->construct($_) } $sth->fetchall_hash;
}

=item $self->can_be_changed_by($contact_obj)

Checks whether ot nor the given contact has permissions on the object

Returns the object if true, undef if false

=cut

sub can_be_changed_by {
    my ( $self, $contact_obj ) = @_;
    my $runtime_object = $self->runtime_host->can_be_changed_by($contact_obj);
    return $runtime_object ? $self : undef;
}

=item Opsview::Host->with_advanced_snmptrap_arrayref

Returns an arrayref of all hosts with at least 1 advanced snmptrap servicecheck. Ordered by name

=cut

sub with_advanced_snmptrap_arrayref {
    my $class = shift;
    my @sc = Opsview::Servicecheck->search( checktype => 4 );
    my %hosts;
    foreach my $s (@sc) {
        $_ = $s->all_hosts;
        foreach my $h (@$_) {
            $hosts{ $h->id } = $h;
        }
    }
    my @hosts = sort { $a->name cmp $b->name } ( values %hosts );
    return \@hosts;
}

=item Opsview::Host->set_snmptrap_tracing( \@hostnames )

Will set these hostnames with snmptrap_tracing. Everything else should be set to 0.
Returns number of hosts set (list could contain hostnames that do not exist)

=cut

sub set_snmptrap_tracing {
    my ( $self, $hostname_arrayref ) = @_;
    my $dbh = $self->db_Main;
    $dbh->do( "UPDATE " . $self->table . " SET snmptrap_tracing=0" );

    return 0 unless @$hostname_arrayref;

    my $sql = SQL::Abstract->new;
    my %where = ( name => [@$hostname_arrayref] );
    my ( $stmt, @bind ) = $sql->update(
        $self->table,
        {
            snmptrap_tracing => 1,
            uncommitted      => 1
        },
        \%where
    );
    my $sth  = $dbh->prepare($stmt);
    my $rows = $sth->execute(@bind);
    return $rows;
}

=item $class->by_hosttemplate($hosttemplate)

Returns a list of host objects, ordered by host name, for the specified hosttemplate

=cut

__PACKAGE__->set_sql( by_hosttemplate => <<"" );
SELECT __ESSENTIAL(me)__
FROM __TABLE__ me, hosthosttemplates
WHERE
 hosthosttemplates.hostid = me.id
 AND hosthosttemplates.hosttemplateid = ?
ORDER BY
 me.name


sub by_hosttemplate {
    my ( $self, $hosttemplate ) = @_;
    my $sth = $self->sql_by_hosttemplate();
    $sth->execute( $hosttemplate->id );
    return $self->sth_to_objects($sth);
}

=item my_type_is

Returns "host"

=cut

sub my_type_is {
    return "host";
}
sub my_web_type {"host"}

=item $string = expand_link_macros($string)

Expand any valid nagios macros within string and return

=cut

sub expand_link_macros {
    my ( $self, $string ) = @_;

    $string =~ s/\$HOSTNAME\$/$self->name/ge;
    $string =~ s/\$HOSTADDRESS\$/$self->ip/ge;
    $string =~ s/\$HOSTGROUP\$/$self->hostgroup/ge;
    $string =~ s/\$MONITORED_BY_NAME\$/$self->monitored_by->name/ge;
    $string =~ s/\$SNMP_VERSION\$/$self->snmp_version/ge;
    $string =~ s/\$SNMP_PORT\$/$self->snmp_port/ge;
    $string =~ s/\$SNMP_COMMUNITY\$/$self->snmp_community/ge;
    $string =~ s/\$SNMPV3_USERNAME\$/$self->snmpv3_username/ge;
    $string =~ s/\$SNMPV3_AUTHPASSWORD\$/$self->snmpv3_authpassword/ge;
    $string =~ s/\$SNMPV3_AUTHPROTOCOL\$/$self->snmpv3_authprotocol/ge;
    $string =~ s/\$SNMPV3_PRIVPROTOCOL\$/$self->snmpv3_privprotocol/ge;
    $string =~ s/\$SNMPV3_PRIVPASSWORD\$/$self->snmpv3_privpassword/ge;

    if ( $string =~ /\$ADDRESSES\$/ ) {
        $_ = $self->other_addresses
          or carp "Macro \$ADDRESSES\$ used, but no other addresses set for "
          . $self->name;
        s/ //g;
        $string =~ s/\$ADDRESSES\$/$_/g;
    }
    if ( $string =~ /\$ADDRESS\d\$/ ) {
        @_ = $self->other_addresses_array;
        for ( my $i = 0; $i < scalar @_; $i++ ) {
            $_ = $_[$i];
            s/ //g;
            my $j = $i + 1;
            $string =~ s/\$ADDRESS$j\$/$_/g;
        }
    }

    return $string;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
