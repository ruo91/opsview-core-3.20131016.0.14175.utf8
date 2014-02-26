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

package Runtime::Searches;

use strict;

use Class::Accessor::Fast;
use base 'Class::Accessor::Fast', 'Runtime';
use Utils::SQL::Abstract;
use Opsview::Utils
  qw(set_highest_service_state set_highest_state max_state max_state_text convert_state_to_text convert_host_state_to_text convert_to_arrayref convert_state_type_to_text);
use Opsview::Config;
use List::Util qw(max);

use Opsview::Performanceparsing;
Opsview::Performanceparsing->init;

my $opsview_db = Opsview::Config->db;
my $runtime_db = Opsview::Config->runtime_db;

__PACKAGE__->mk_accessors( qw(list summary) );

=head1 NAME

Runtime::Searches - Searches the runtime DB for hostgroup, host and service information

=head1 DESCRIPTION

Holds all the searches of the runtime DB to retrieve status summaries depending on
whether specified by hostgroup, host or service.

Returns an arrayref of (template toolkit) format:

  status.hosts.0.handled
  status.hosts.0.unhandled
  status.hosts.1.handled
  status.hosts.1.unhandled
  status.hosts.2.handled
  status.hosts.2.unhandled
  status.hosts.3.handled
  status.hosts.3.unhandled
  status.hosts.handled       # total number of unhandled
  status.hosts.unhandled
  status.hosts.total
  status.services.0.handled
  ...
  status.services.3.unhandled
  status.services.handled
  status.services.unhandled
  status.services.total

=head1 METHODS

=item RuntimeDB::Searches->list_hosts_summarize_services_by_hostgroup( $contact_object, $runtime_hostgroup_object )

Returns arrayref based on contact_object and Runtime::Hostgroup object.
%args can be ( filter => "handled" | "unhandled", state => 0, 1, 2 )

Extra data:
  status.host       # name of host
  status.host_state # status of host
  status.icon       # icon for host

=cut

sub list_hosts_summarize_services_by_hostgroup {
    my ( $class, $contact_object, $hostgroup, $args ) = @_;
    my $status = {};
    my $downtimes =
      $class->downtimes_by_hostgroup_host_hash( $contact_object, $hostgroup );

    #<<< Ignore perltidy - retain manual style for easier reading
    my $select = [
        "opsview_host_services.hostname as host",
        "opsview_hosts.alias as alias",
        "opsview_host_services.host_object_id as host_object_id",
        "opsview_hosts.icon_filename as icon",
        "nagios_hoststatus.current_state as host_state",
        "nagios_hoststatus.state_type as host_state_type",
        "UNIX_TIMESTAMP(nagios_hoststatus.last_state_change) as host_last_state_change_timev",
        "nagios_hoststatus.is_flapping as flapping",
        "nagios_hoststatus.problem_has_been_acknowledged as acknowledged",
        "(nagios_hoststatus.current_state = 1 and nagios_hoststatus.problem_has_been_acknowledged != 1 and nagios_hoststatus.scheduled_downtime_depth = 0) as host_unhandled",
        "nagios_servicestatus.current_state as service_state",
        "opsview_host_services.service_object_id as service_object_id",
        "(nagios_servicestatus.current_state != 0 and nagios_hoststatus.current_state = 0 and nagios_servicestatus.problem_has_been_acknowledged!=1 and nagios_servicestatus.scheduled_downtime_depth = 0) as service_unhandled",
        "count(*) as total",
    ];
    #>>>
    my $tables =
      [qw(opsview_host_services opsview_hosts opsview_hostgroup_hosts)];

    my $where = {
        "opsview_hosts.id" => \"= opsview_host_services.host_object_id",
        "opsview_hostgroup_hosts.host_object_id" => \
          "= opsview_host_services.host_object_id",
        "opsview_hostgroup_hosts.hostgroup_id" => $hostgroup->id,
    };
    my $order_by = {
        order_by => ["host"],
        group_by => [qw(host service_state service_unhandled)],
    };

    if ( $contact_object && ( !$contact_object->can_view_all ) ) {
        filter_by_contact_id( $tables, $where, $contact_object->id );
    }

    $class->common_filters_host( $where, $args );
    $class->common_filters_service( $where, $args );

    # Downtimes lookup here like list_services?

    push @$tables, qw(nagios_hoststatus nagios_servicestatus);
    $where->{"opsview_host_services.host_object_id"} =
      \"= nagios_hoststatus.host_object_id";
    $where->{"opsview_host_services.service_object_id"} =
      \"= nagios_servicestatus.service_object_id";

    $class->common_filters_state( $where, $args );

    $class->common_filters_unhandled( $where, $args, $order_by );

    my ( $stmt, @bind ) =
      Utils::SQL::Abstract->new->select( $tables, $select, $where, $order_by );
    my $dbh = $class->db_Main;
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(@bind);
    return $class->create_hosts_summarised_services_resultset( $sth, $downtimes,
        $dbh, $args );
}

sub create_hosts_summarised_services_resultset {
    my ( $class, $sth, $downtimes, $dbh, $args ) = @_;
    my $now       = time;
    my $comments  = $class->list_comments;
    my $host      = "";
    my $icon      = "";
    my $handled   = 0;
    my $unhandled = 0;
    my $summary   = {
        host => {
            total     => 0,
            unhandled => 0
        },
        service => {
            total     => 0,
            unhandled => 0
        }
    };
    my @hosts     = ();
    my $this_host = {
        name      => "",
        icon      => "",
        state     => "",
        unhandled => "",
        summary   => {}
    };

    if ( defined $sth )
    { # A hacky if here, but allows us to return a consistent summary if $sth is empty
        while ( my $hash = $sth->fetchrow_hashref ) {
            my $key;
            if ( $host ne $hash->{host} ) {
                if ($host) {
                    $this_host->{name}                 = $host;
                    $this_host->{icon}                 = $icon;
                    $this_host->{summary}->{unhandled} = $unhandled;
                    $this_host->{summary}->{handled}   = $handled;
                    $this_host->{summary}->{total}     = $handled + $unhandled;
                    push @hosts, $this_host;
                    $this_host = {
                        name      => "",
                        icon      => "",
                        state     => "",
                        unhandled => "",
                        summary   => {
                            handled   => 0,
                            unhandled => 0
                        }
                    };
                    $handled   = 0;
                    $unhandled = 0;
                }
                $host               = $hash->{host};
                $icon               = $hash->{icon};
                $this_host->{alias} = $hash->{alias};
                $this_host->{state} =
                  convert_host_state_to_text( $hash->{host_state} );
                $this_host->{state_type} =
                  convert_state_type_to_text( $hash->{host_state_type} );
                $this_host->{state_duration} =
                  $now - $hash->{host_last_state_change_timev};
                $this_host->{unhandled}    = $hash->{host_unhandled};
                $this_host->{flapping}     = 1 if $hash->{flapping};
                $this_host->{acknowledged} = 1 if $hash->{acknowledged};
                $this_host->{comments} = $comments->{ $hash->{host_object_id} }
                  if ( defined( $comments->{ $hash->{host_object_id} } ) );
                $summary->{host}
                  ->{ convert_host_state_to_text( $hash->{host_state} ) }++;
                $summary->{host}->{unhandled}++ if $hash->{host_unhandled};
                $summary->{host}->{total}++;

                if ( $downtimes->{$host} ) {

                    # This uses a different downtime query to get the list. It doesn't use _downtimes_hash
                    $this_host->{downtime} = $downtimes->{$host};
                }
                else {
                    $this_host->{downtime} = 0;
                }
            }
            if ( $hash->{service_unhandled} ) {
                $key = "unhandled";
                $unhandled += $hash->{total};
                $summary->{service}->{unhandled} += $hash->{total};
            }
            else {
                $key = "handled";
                $handled += $hash->{total};
            }
            $_ = convert_state_to_text( $hash->{service_state} );
            $this_host->{summary}->{$_}->{$key} = $hash->{total};
            $summary->{service}->{$_} += $hash->{total};
            $summary->{service}->{total} += $hash->{total};
        }

        # Need a nice way of not duplicating this with above
        # Need if here because could have no hosts found
        if ($host) {
            $this_host->{name}                 = $host;
            $this_host->{icon}                 = $icon;
            $this_host->{summary}->{unhandled} = $unhandled;
            $this_host->{summary}->{handled}   = $handled;
            $this_host->{summary}->{total}     = $handled + $unhandled;
            push @hosts, $this_host;
        }
    } # End if $sth

    $summary->{host}->{handled} =
      $summary->{host}->{total} - $summary->{host}->{unhandled};
    $summary->{service}->{handled} =
      $summary->{service}->{total} - $summary->{service}->{unhandled};
    $summary->{unhandled} =
      $summary->{host}->{unhandled} + $summary->{service}->{unhandled};
    $summary->{handled} =
      $summary->{host}->{handled} + $summary->{service}->{handled};
    $summary->{total} =
      $summary->{host}->{total} + $summary->{service}->{total};
    return $class->new(
        {
            list    => \@hosts,
            summary => $summary
        }
    );
}

# Lots of assumptions about the call to this function. However, since this is a developer function
# this is acceptable
# Returns a hash with $hash->{$key} = {
#   state = 1 (downtime scheduled) or 2 (downtime in progress),
#   username = username of downtime applier,
#   comment = downtime comment,
# }
# $key is dependent on input. Will take the max $key, so if hostgroup, will give you the highest downtime state for all things beneath
# As there are possibly multiple downtimes per object, will take the earliest downtime comment if it has already been started
sub _downtimes_hash {
    my ( $self, $args ) = @_;
    my $dbh = Runtime->db_Main;
    my $sql = Utils::SQL::Abstract->new;

    # Take copies so as not to affect calling routines. Note: These are light copies
    my $tables = [ @{ $args->{tables} } ];
    my $where  = { %{ $args->{where} } };
    push @$tables, "nagios_scheduleddowntime";

    my $key_column;
    if ( $args->{key} eq "hostgroup" ) {
        $key_column = "opsview_hostgroups.id";
        $where->{"nagios_scheduleddowntime.object_id"} = [
            \"= opsview_hostgroup_hosts.host_object_id",
            \"= opsview_host_services.service_object_id"
        ];
    }
    elsif ( $args->{key} eq "keyword" ) {
        $key_column = "$opsview_db.keywords.name";
        $where->{"nagios_scheduleddowntime.object_id"} =
          \"= opsview_viewports.object_id";
    }
    elsif ( $args->{key} eq "object" ) {
        $key_column = "nagios_scheduleddowntime.object_id";

        # A possible speed up for this in future is to only check downtimes where already started. Not convinced this is useful yet
        #$where->{ "nagios_scheduleddowntime.was_started" } = 0;
        $where->{"nagios_scheduleddowntime.object_id"} = [
            \"= opsview_host_services.host_object_id",
            \"= opsview_host_services.service_object_id"
        ];
    }
    else {
        die "No key" unless exists $args->{key};
        die "Unexpected key: " . $args->{key};
    }

    my $order_by =
      { order_by => [qw(nagios_scheduleddowntime.scheduled_start_time)], };
    my ( $stmt, @bind ) = $sql->select(
        $tables,
        [
            $key_column,
            "nagios_scheduleddowntime.was_started as started",
            "nagios_scheduleddowntime.author_name",
            "nagios_scheduleddowntime.comment_data"
        ],
        $where,
        $order_by
    );
    my $hash = {};
    my $sth  = $dbh->prepare_cached($stmt);
    $sth->execute(@bind);
    while ( my ( $key, $started, $username, $comment ) = $sth->fetchrow_array )
    {
        if ($started) {
            if ( !exists $hash->{$key} || $hash->{$key}->{state} < 2 ) {
                $hash->{$key} = {
                    state    => 2,
                    username => $username,
                    comment  => $comment,
                };
            }
        }
        else {
            if ( !exists $hash->{$key} || $hash->{$key}->{state} < 1 ) {
                $hash->{$key} = {
                    state    => 1,
                    username => $username,
                    comment  => $comment,
                };
            }
        }
    }
    return $hash;
}

=item Runtime::Searches->downtimes_by_hostgroup_host_hash( $contact_object, $runtime_hostgroup_object );

Returns a hash with hostnames of all hosts within a given hostgroup
containing a scheduled downtime

=cut

sub downtimes_by_hostgroup_host_hash {
    my ( $self, $contact_object, $runtime_hostgroup_object ) = @_;
    my $dbh = Runtime->db_Main;
    my ( $select, $from, $where, $where1, $where2 );

    if ( !$contact_object->can_view_all ) {
        $where .= qq{
			o.service_object_id = cs.service_object_id
			AND cs.contactid = } . $contact_object->id . qq{
			AND
		};
        $from .= qq{
			opsview_contact_services cs,
		};
    }

    $select .= qq{
		o.hostname as hostname,
		d.was_started as started
	};
    $from .= qq{
		opsview_host_services o,
		nagios_scheduleddowntime d,
		opsview_hostgroup_hosts hg
	};
    $where .= qq{
		hg.hostgroup_id = } . $runtime_hostgroup_object->id . qq{
		AND hg.host_object_id = o.host_object_id
		AND };
    $where1 = qq{
		o.host_object_id = d.object_id
		AND d.downtime_type = 2
	};
    $where2 = qq{
		o.service_object_id = d.object_id
		AND d.downtime_type = 1
	};

    my $hash = {};
    my $stmt = qq{
		SELECT hostname, max(started) FROM (
			(
				SELECT $select
				FROM $from
				WHERE $where
					$where1
			) UNION (
				SELECT $select
				FROM $from
				WHERE $where
					$where2
			)
		) AS derived
		GROUP BY hostname
	};

    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute();
    while ( my @id = $sth->fetchrow_array ) {
        if ( $id[1] ) {
            $hash->{ $id[0] } = 2
              if ( !$hash->{ $id[0] } || $hash->{ $id[0] } lt 2 );
        }
        else {
            $hash->{ $id[0] } = 1
              if ( !$hash->{ $id[0] } || $hash->{ $id[0] } lt 1 );
        }
    }
    return $hash;
}

# These are common filters applied to the new style SQL::Abstract queries
sub common_filters {
    my ( $self, $where, $args, $order_by ) = @_;

    # Some of these could be arrayrefs - catalyst takes care of that for us
    $self->common_filters_state( $where, $args );
    $self->common_filters_service( $where, $args );
    $self->common_filters_host( $where, $args );
    $self->common_filters_unhandled( $where, $args, $order_by );
}

sub common_filters_host {
    my ( $self, $where, $args ) = @_;
    $where->{"opsview_host_services.hostname"} = { -like => $args->{host} }
      if exists $args->{host};
}

sub common_filters_service {
    my ( $self, $where, $args ) = @_;
    $where->{"opsview_host_services.servicename"} =
      { -like => $args->{servicecheck} }
      if exists $args->{servicecheck};
}

sub common_filters_state {
    my ( $self, $where, $args ) = @_;
    $where->{"nagios_servicestatus.current_state"} = $args->{state}
      if exists $args->{state};
    $where->{"nagios_hoststatus.current_state"} = $args->{host_state}
      if exists $args->{host_state};
}

# Filter based on the unhandled field
sub common_filters_unhandled {
    my ( $self, $where, $args, $order_by ) = @_;

    my @having_filter;
    if ( exists $args->{filter} && $args->{filter} eq "handled" ) {

        # Query needs to be different here because we are trying to list services that have a failure
        if ( exists $args->{includeunhandledhosts} ) {
            push @having_filter,
              {
                service_unhandled => 0,
                host_unhandled    => 1,
                service_state     => { '!=' => 0 }
              };
        }
        else {
            push @having_filter, { service_unhandled => 0 };
        }
    }
    elsif ( exists $args->{filter} && $args->{filter} eq "unhandled" ) {

        # Need to have this flag because there are two different views required:
        #  * Filter on all unhandled services (default - links off HH pages)
        #  * Filter on all unhandled services and all problems states on hosts in an unhandled state (All Unhandled link on sidenav)
        if ( exists $args->{includeunhandledhosts} ) {

            # <=> service_unhandled = 1 or (host_unhandled = 1 and service_state != 0)
            push @having_filter,
              [
                { service_unhandled => 1 },
                {
                    host_unhandled => 1,
                    service_state  => { '!=' => 0 }
                }
              ];
        }
        else {
            push @having_filter, { service_unhandled => 1 };
        }
    }
    if ( exists $args->{host_filter} ) {
        if ( $args->{host_filter} eq "handled" ) {
            push @having_filter, { host_unhandled => 0 };
        }
        elsif ( $args->{host_filter} eq "unhandled" ) {
            push @having_filter, { host_unhandled => 1 };
        }
    }
    if (@having_filter) {
        $order_by->{having} = { "-and" => \@having_filter };
    }
}

# Convenience function. Need to pass in references, otherwise will localise
sub filter_by_contact_id {
    my ( $tables, $where, $contact_id ) = @_;
    push @$tables, "opsview_contact_services";
    $where->{"opsview_contact_services.service_object_id"} =
      \"= opsview_host_services.service_object_id";
    $where->{"opsview_contact_services.contactid"} = $contact_id;
}

=item RuntimeDB::Searches->list_services( $contact_object, \%args )

Returns a list and summary of services. %args is the parameter array where possible values are:
  * state={ok|warning|critical|unknown}
  * host={name} (can include % wildcards)
  * host_state={up|down|unreachable}
  * hostgroup={number}
  * servicecheck={name} (can include % wildcards)
  * filter={handled|unhandled}
  * includedunhandledhosts
  * order={state|host_state|host|service} - default host,service
  * downtime_start_time = datetime
  * downtime_comment = string

Returns a list and summary of services

=cut

# $contact_object maybe empty, eg for /viewport pages
sub list_services {
    my ( $class, $contact_object, $args ) = @_;

    # A service is considered unhandled if:
    #  - the state of the service is not OK and
    #  - the service has not been acknowledged and
    #  - the service is not in a downtime and
    #  - the host is up
    # Otherwise, the service is handled
    # Need the DISTINCT because keywords may list the same item multiple times
    # Note: TIME_TO_SEC is not good to use because (1) bug in mysql prior to 5.0.36, (2) only returns in same day
    #<<< Ignore perltidy - retain manual list style
    my $select = [
        "DISTINCT(opsview_host_services.service_object_id) as service_object_id",
        "opsview_host_services.host_object_id as host_object_id",
        "opsview_host_services.hostname as host",
        "opsview_hosts.alias as alias",
        "opsview_hosts.icon_filename as icon",
        "opsview_hosts.num_interfaces as num_interfaces",
        "opsview_hosts.num_services as num_services",
        "nagios_hoststatus.current_state as host_state",
        "nagios_hoststatus.state_type as host_state_type",
        "nagios_hoststatus.is_flapping as host_flapping",
        "nagios_hoststatus.problem_has_been_acknowledged as host_acknowledged",
        "(nagios_hoststatus.current_state = 1 and nagios_hoststatus.problem_has_been_acknowledged != 1 and nagios_hoststatus.scheduled_downtime_depth = 0) as host_unhandled",
        "nagios_hoststatus.output as host_output",
        "nagios_hoststatus.current_check_attempt as host_current_check_attempt",
        "nagios_hoststatus.max_check_attempts as host_max_check_attempts",
        "CONVERT_TZ(nagios_hoststatus.last_check, '+00:00', 'SYSTEM') as host_last_check",
        "UNIX_TIMESTAMP(nagios_hoststatus.last_state_change) as host_last_state_change_timev",
        "opsview_host_services.servicename as service",
        "nagios_servicestatus.current_state as service_state",
        "nagios_servicestatus.state_type as service_state_type",
        "nagios_servicestatus.is_flapping as service_flapping",
        "nagios_servicestatus.problem_has_been_acknowledged as service_acknowledged",
        "nagios_servicestatus.output as service_output",
        "nagios_servicestatus.perfdata as service_perfdata",
        "(nagios_servicestatus.current_state != 0 and nagios_hoststatus.current_state = 0 and nagios_servicestatus.problem_has_been_acknowledged!=1 and nagios_servicestatus.scheduled_downtime_depth = 0) as service_unhandled",
        "opsview_host_services.perfdata_available as perfdata_available",
        "opsview_host_services.markdown_filter as markdown_filter",
        "nagios_servicestatus.current_check_attempt as current_check_attempt",
        "nagios_servicestatus.max_check_attempts as max_check_attempts",
        "CONVERT_TZ(nagios_servicestatus.last_check, '+00:00', 'SYSTEM') as last_check",
        "UNIX_TIMESTAMP(nagios_servicestatus.last_state_change) as last_state_change_timev",
    ];
    #>>>
    my $tables = [qw(opsview_host_services opsview_hosts)];

    # Don't use opsview_host_services.host_object_id as the key as this is used elsewhere
    my $where =
      { "opsview_hosts.id" => \"= opsview_host_services.host_object_id" };
    my $order_by = { order_by => [qw(host service)] };

    # FILTERING
    if ( $args->{changeaccess} ) {
        if ( $contact_object && $contact_object->has_access("ACTIONALL") ) {

            # Do nothing, ie, return entire list
        }
        elsif ( $contact_object && $contact_object->has_access("ACTIONSOME") ) {
            filter_by_contact_id( $tables, $where, $contact_object->id );
        }
        else {

            # No change access available, return an empty summary
            return $class->create_service_resultset();
        }
    }
    else {

        # Can use notification parameter to only list services that would get notified for this contact
        if ( $contact_object
            && ( !$contact_object->can_view_all || $args->{notifications} ) )
        {
            filter_by_contact_id( $tables, $where, $contact_object->id );
        }
    }
    if ( exists $args->{hostgroupid} ) {
        push @$tables, "opsview_hostgroup_hosts";
        $where->{"opsview_hostgroup_hosts.host_object_id"} =
          \"= opsview_host_services.host_object_id";
        $where->{"opsview_hostgroup_hosts.hostgroup_id"} =
          [ $args->{hostgroupid} ];
    }
    if ( exists $args->{keyword} ) {
        push @$tables, "opsview_viewports";
        $where->{"opsview_viewports.keyword"} = $args->{keyword};
        $where->{"opsview_viewports.host_object_id"} =
          \"= opsview_host_services.host_object_id";
        $where->{"opsview_viewports.object_id"} =
          \"= opsview_host_services.service_object_id";
    }
    if ( exists $args->{monitoredby} ) {
        $where->{"opsview_hosts.monitored_by"} = $args->{monitoredby};
    }
    if ( $args->{includeperfdata} ) {
        push @$tables, "opsview_performance_metrics";
        $where->{"opsview_performance_metrics.service_object_id"} =
          \"= opsview_host_services.service_object_id";
        push @$select, 'opsview_performance_metrics.metricname as metricname';
    }

    $class->common_filters_host( $where, $args );
    $class->common_filters_service( $where, $args );

    my $downtimes = $class->_downtimes_hash(
        {
            key    => "object",
            where  => $where,
            tables => $tables
        }
    );

    # Add status joins here. This is because the downtime calculations above do not require these tables
    push @$tables, qw(nagios_hoststatus nagios_servicestatus);
    $where->{"opsview_host_services.host_object_id"} =
      \"= nagios_hoststatus.host_object_id";
    $where->{"opsview_host_services.service_object_id"} =
      \"= nagios_servicestatus.service_object_id";

    # Some of these could be arrayrefs - catalyst takes care of that for us
    $class->common_filters_state( $where, $args );

    # Move this lower because will check for downtimes further up
    if (   exists $args->{downtime_start_time}
        && exists $args->{downtime_comment} )
    {
        push @$tables, "nagios_scheduleddowntime";
        $where->{"nagios_scheduleddowntime.scheduled_start_time"} =
          $args->{downtime_start_time};
        $where->{"nagios_scheduleddowntime.comment_data"} =
          $args->{downtime_comment};

        # Logic used to be that if a host was in downtime, all the services are also in downtime
        # This was because it was possible in Nagios to only set a host in downtime.
        # However, Opsview UI host downtime will sets all services to be in downtime too
        # So for purposes of listing services, we only list the services which have an associated
        # downtime entry, rather than try to see if hosts are also in downtime
        #$where->{ "nagios_scheduleddowntime.object_id" } = [ \"= nagios_hoststatus.host_object_id", \"= nagios_servicestatus.service_object_id" ];
        #$order_by->{group_by} = [qw(host_object_id service_object_id)];
        $where->{"nagios_scheduleddowntime.object_id"} =
          \"= nagios_servicestatus.service_object_id";
    }

    if ( exists $args->{order} ) {
        my %valid_orderbys = (
            state                  => "service_state_priority",
            state_desc             => "service_state_priority DESC",
            service                => "service",
            service_desc           => "service DESC",
            host                   => "host",
            host_desc              => "host DESC",
            host_state             => "host_state",
            host_state_desc        => "host_state DESC",
            last_check             => "last_check",
            last_check_desc        => "last_check DESC",
            last_state_change      => "last_state_change_timev",
            last_state_change_desc => "last_state_change_timev DESC",
        );

        # Need to add an extra select column if these orderbys are specified
        my %add_select = (
            state      => 1,
            state_desc => 1
        );
        my $flag = 0;
        $_ = convert_to_arrayref( $args->{order} );
        $order_by->{order_by} = [
            map {
                $flag = 1 if exists $add_select{$_};
                exists $valid_orderbys{$_} ? $valid_orderbys{$_} : ()
            } @$_
        ];
        if ($flag) {

            # Little bit of magic here
            # Idea is that if a host has failed, push it higher up the service_state_priority
            # Also, reorder so that UNKNOWNs are lower than WARNINGs and CRITICALs
            my $service_reordering =
              "IF(nagios_servicestatus.current_state=3, 0.5, nagios_servicestatus.current_state)";
            if ( $args->{includeunhandledhosts} ) {
                $service_reordering =
                  "IF(nagios_hoststatus.current_state=0, $service_reordering, nagios_hoststatus.current_state*10)";
            }
            push @$select, "$service_reordering as service_state_priority";
        }
    }

    $class->common_filters_unhandled( $where, $args, $order_by );

    my ( $stmt, @bind ) =
      Utils::SQL::Abstract->new->select( $tables, $select, $where, $order_by, );
    my $dbh = $class->db_Main;
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(@bind);
    return $class->create_service_resultset( $sth, $downtimes, $dbh, $args );
}

sub create_service_resultset {
    my ( $class, $sth, $downtimes, $dbh, $args ) = @_;
    my $now      = time;
    my $host     = "";
    my $icon     = "";
    my $comments = $class->list_comments;
    my $summary  = {
        host => {
            total     => 0,
            unhandled => 0
        },
        service => {
            total     => 0,
            unhandled => 0,
            handled   => 0
        }
    };
    my @hosts;
    my $this_host = {
        name      => "",
        icon      => "",
        state     => "",
        unhandled => "",
        summary   => {
            handled   => 0,
            unhandled => 0
        },
        services => []
    };
    my $services                = [];
    my $service_metrics         = [];
    my $service_metrics_by_name = {};
    my $this_service;
    my $key;
    my $seen_hosts             = {};
    my $last_service_object_id = 0;

    if ( defined $sth )
    { # A hacky if here, but allows us to return a consistent summary if $sth is empty
        while ( my $hash = $sth->fetchrow_hashref ) {
            if ( $host ne $hash->{host} ) {
                if ($host) {
                    $this_host->{summary}->{total} =
                        $this_host->{summary}->{handled}
                      + $this_host->{summary}->{unhandled};
                    set_highest_service_state( $this_host->{summary} );
                    $this_host->{services} = $services;
                    push @hosts, $this_host;
                    $services  = [];
                    $this_host = {
                        name      => "",
                        icon      => "",
                        state     => "",
                        unhandled => "",
                        summary   => {
                            handled   => 0,
                            unhandled => 0
                        },
                        services => []
                    };
                }
                $host               = $hash->{host};
                $this_host->{name}  = $host;
                $this_host->{alias} = $hash->{alias};
                $this_host->{icon}  = $hash->{icon};
                $this_host->{state} =
                  convert_host_state_to_text( $hash->{host_state} );
                $this_host->{state_type} =
                  convert_state_type_to_text( $hash->{host_state_type} );
                $this_host->{unhandled}    = $hash->{host_unhandled};
                $this_host->{flapping}     = 1 if ( $hash->{host_flapping} );
                $this_host->{acknowledged} = 1
                  if ( $hash->{host_acknowledged} );
                $this_host->{comments} = $comments->{ $hash->{host_object_id} }
                  if ( defined $comments->{ $hash->{host_object_id} } );
                $this_host->{last_check} = $hash->{host_last_check}
                  || '1970-01-01 00:00:00';
                $this_host->{current_check_attempt} =
                  $hash->{host_current_check_attempt};
                $this_host->{max_check_attempts} =
                  $hash->{host_max_check_attempts};
                $this_host->{state_duration} =
                  $now - $hash->{host_last_state_change_timev};
                $this_host->{output} = $hash->{host_output};

                if ( my $dt = $downtimes->{ $hash->{host_object_id} } ) {
                    $this_host->{downtime}          = $dt->{state};
                    $this_host->{downtime_username} = $dt->{username};
                    $this_host->{downtime_comment}  = $dt->{comment};
                }
                else {
                    $this_host->{downtime} = 0;
                }

                $this_host->{num_interfaces} = $hash->{num_interfaces};
                $this_host->{num_services}   = $hash->{num_services};

                # Need this because when ordering has changed, same host may appear
                unless ( exists $seen_hosts->{$host} ) {
                    $seen_hosts->{$host}++;
                    $summary->{host}
                      ->{ convert_host_state_to_text( $hash->{host_state} ) }++;
                    $summary->{host}->{unhandled}++ if $hash->{host_unhandled};
                    $summary->{host}->{total}++;
                }
            }
            $this_service = {};
            if ( $args->{includeperfdata} ) {

                # You could have another row for the same service
                my $first_metric_for_service = 0;
                if ( $hash->{service_object_id} != $last_service_object_id ) {
                    $first_metric_for_service = 1;
                    $last_service_object_id   = $hash->{service_object_id};
                    $service_metrics          = [];
                    $service_metrics_by_name  = {};
                    my $perfs = Opsview::Performanceparsing->parseperfdata(
                        servicename => $hash->{service},
                        output      => $hash->{service_output},
                        perfdata    => $hash->{service_perfdata}
                    );
                    foreach my $p (@$perfs) {
                        next if ( $p->value eq "U" );

                        my $h = {
                            name  => $p->label,
                            uom   => $p->uom,
                            value => $p->value
                        };

                        push @$service_metrics, $h;
                        $service_metrics_by_name->{ $h->{name} } = $h;
                    }
                    $this_service->{metrics} = $service_metrics;
                }
                if ( !exists $service_metrics_by_name->{ $hash->{metricname} } )
                {
                    push @$service_metrics, { name => $hash->{metricname} };
                }
                if ( !$first_metric_for_service ) {

                    # Can ignore rest because service should be exactly the same as prior rows
                    next;
                }
            }
            $this_service->{name}              = $hash->{service};
            $this_service->{service_object_id} = $hash->{service_object_id};
            $this_service->{state} =
              convert_state_to_text( $hash->{service_state} );
            $this_service->{state_type} =
              convert_state_type_to_text( $hash->{service_state_type} );
            $this_service->{flapping} = 1 if ( $hash->{service_flapping} );
            if ( $hash->{service_acknowledged} ) {
                $this_service->{acknowledged} = 1;

                # This is likely to be heavy, so only do when requested, eg in viewports
                # This cannot be part of the original SQL query because there can be multiple acknowledgements per service
                # Note the limit 1 and order by
                if ( exists $args->{includehandleddetails} ) {
                    my $ack = $dbh->selectrow_hashref(
                        "SELECT author_name, comment_data FROM nagios_acknowledgements WHERE object_id=? ORDER BY entry_time DESC LIMIT 1",
                        {}, $hash->{service_object_id}
                    );
                    $this_service->{acknowledged_author} = $ack->{author_name};
                    $this_service->{acknowledged_comment} =
                      $ack->{comment_data};
                }
            }
            $this_service->{comments} =
              $comments->{ $hash->{service_object_id} }
              if ( defined $comments->{ $hash->{service_object_id} } );
            $this_service->{output}             = $hash->{service_output};
            $this_service->{unhandled}          = $hash->{service_unhandled};
            $this_service->{perfdata_available} = $hash->{perfdata_available};
            $this_service->{markdown}           = $hash->{markdown_filter};
            $this_service->{current_check_attempt} =
              $hash->{current_check_attempt};
            $this_service->{max_check_attempts} = $hash->{max_check_attempts};
            $this_service->{last_check}         = $hash->{last_check};
            $this_service->{state_duration} =
              $now - $hash->{last_state_change_timev};

            # Downtime calculation. Work out whether host or service is higher state, then use username and comment
            # from that one
            my $sdt = $downtimes->{ $hash->{service_object_id} };
            my $hdt = $downtimes->{ $hash->{host_object_id} };
            if ( ( $sdt->{state} || 0 ) < ( $hdt->{state} || 0 ) ) {
                $this_service->{downtime}          = $hdt->{state};
                $this_service->{downtime_username} = $hdt->{username};
                $this_service->{downtime_comment}  = $hdt->{comment};
            }
            elsif ( $sdt->{state} ) {
                $this_service->{downtime}          = $sdt->{state};
                $this_service->{downtime_username} = $sdt->{username};
                $this_service->{downtime_comment}  = $sdt->{comment};
            }
            else {
                $this_service->{downtime} = 0;
            }

            push @$services, $this_service;
            if ( $hash->{service_unhandled} ) {
                $key = "unhandled";
            }
            else {
                $key = "handled";
            }
            $this_host->{summary}->{$key}++;
            $this_host->{summary}->{ $this_service->{state} }++;
            $summary->{service}->{ $this_service->{state} }++;
            $summary->{service}->{$key}++;
            $summary->{service}->{total}++;
        }

        # Need a nice way of not duplicating this with above
        # Need if here because could have no hosts found
        if ($host) {
            $this_host->{summary}->{total} =
                $this_host->{summary}->{handled}
              + $this_host->{summary}->{unhandled};
            set_highest_service_state( $this_host->{summary} );
            $this_host->{services} = $services;
            push @hosts, $this_host;
        }

    } # End if $sth

    $summary->{host}->{handled} =
      $summary->{host}->{total} - $summary->{host}->{unhandled};
    $summary->{unhandled} =
      $summary->{host}->{unhandled} + $summary->{service}->{unhandled};
    $summary->{handled} =
      $summary->{host}->{handled} + $summary->{service}->{handled};
    $summary->{total} =
      $summary->{host}->{total} + $summary->{service}->{total};
    return $class->new(
        {
            list    => \@hosts,
            summary => $summary
        }
    );
}

=item list_summarized_hosts_services

Returns a { list => [], summary => {} } indexed by hostgroup or keyword

=cut

sub list_summarized_hosts_services {
    my ( $class, $contact_object, $input_args ) = @_;

    # Take a copy of args. Beware that this is not a clone, so references still point to original objects
    # We do this so we can introduce internal args
    my $args = {%$input_args};
    my $downtimes;

    my $dbh = $class->db_Main;

    # This is the select query to get information required for this type of call
    #<<< Ignore perltidy - retain manual list style
    my $select = [
        "nagios_hoststatus.current_state as host_state",
        "(nagios_hoststatus.current_state = 1 and nagios_hoststatus.problem_has_been_acknowledged != 1 and nagios_hoststatus.scheduled_downtime_depth = 0) as host_unhandled",
        "nagios_servicestatus.current_state as service_state",
        "(nagios_servicestatus.current_state != 0 and nagios_hoststatus.current_state = 0 and nagios_servicestatus.problem_has_been_acknowledged!=1 and nagios_servicestatus.scheduled_downtime_depth = 0) as service_unhandled",
        "count(*) as total",
    ];
    #>>>
    my $tables = [];
    my $where  = {};
    my $order_by;
    if ( $args->{summarizeon} eq "keyword" ) {
        push @$tables, "opsview_viewports", "$opsview_db.keywords";
        $where->{"opsview_viewports.viewportid"} = \"= $opsview_db.keywords.id";
        $where->{"$opsview_db.keywords.enabled"} = 1;

        $where->{"$opsview_db.keywords.name"} = $args->{keyword}
          if exists $args->{keyword};
        $downtimes = $class->_downtimes_hash(
            {
                key    => "keyword",
                where  => $where,
                tables => $tables
            }
        );

        # Need from_opsview_web check due to unauthenticated access via web
        # But plugins that call here will not have a contact setup
        if ( $args->{from_opsview_web} ) {
            if ( !$contact_object ) {
                $where->{"$opsview_db.keywords.public"} = 1;
            }
            else {

                # This part is similar to code used in Viewport.pm - when updated to DBIx::Class, update there too
                # Apply keyword authentication
                if (   $contact_object->can_view_all
                    || $contact_object->role->all_keywords )
                {
                }
                else {

                    # This means: either I have specific access to this keyword, or it is a public viewport
                    $where->{"-or"} = [
                        {
                            "$opsview_db.role_access_keywords.roleid" =>
                              $contact_object->role->id
                        },
                        { "$opsview_db.keywords.public" => 1 }
                    ];

                    # Terrible hack below to do the LEFT JOIN, but works right
                    $args->{do_that_dirty_left_join_to_role_access_keywords} =
                      1;
                }

            }
        }

        # Need to define this after the downtimes call
        push @$select, "opsview_viewports.host_object_id as host_object_id",
          "$opsview_db.keywords.description as description",
          "$opsview_db.keywords.name as keyword_name";
        $where->{"opsview_viewports.host_object_id"} =
          \"= nagios_hoststatus.host_object_id";
        $where->{"opsview_viewports.object_id"} =
          \"= nagios_servicestatus.service_object_id";
        $order_by = {
            group_by =>
              [qw(keyword_name host_object_id service_state service_unhandled)],
            order_by => [qw(keyword_name host_object_id)],
        };
        $args->{ignore_access} = 1;
    }
    elsif ( $args->{summarizeon} eq "hostgroup" ) {
        push @$tables, "opsview_hostgroups", "opsview_hostgroup_hosts",
          "opsview_host_services";

        # Query is slightly different for a leaf hostgroup
        # Need to convert to matpath (and drop opsview_hostgroup_hosts) in future, but this will require a pre-query so this is not so bad
        my $hostgroup_is_leaf = $dbh->selectrow_array(
            "SELECT (rgt-lft=1) FROM opsview_hostgroups WHERE id=?",
            {}, $args->{hostgroupid} );
        if ($hostgroup_is_leaf) {
            $where->{"opsview_hostgroups.id"} = $args->{hostgroupid};
        }
        else {
            $where->{"opsview_hostgroups.parentid"} = $args->{hostgroupid};
        }
        $where->{"opsview_hostgroup_hosts.hostgroup_id"} =
          \"= opsview_hostgroups.id";
        $where->{"opsview_hostgroup_hosts.host_object_id"} =
          \"= opsview_host_services.host_object_id";
        $downtimes = $class->_downtimes_hash(
            {
                key    => "hostgroup",
                where  => $where,
                tables => $tables
            }
        );

        push @$select, "opsview_host_services.host_object_id as host_object_id",
          "opsview_hostgroups.name as hostgroup_name",
          "opsview_hostgroups.id as hostgroup_id";
        $order_by = {

            # Use opsview_hostgroups.id instead of hostgroup_id because hostgroup_id is ambiguous - could mean opsview_hostgroup_hosts.hostgroup_id
            group_by => [
                qw(opsview_hostgroups.id host_object_id service_state service_unhandled)
            ],
            order_by =>
              [qw(hostgroup_name opsview_hostgroups.id host_object_id)],
        };
        $where->{"opsview_host_services.host_object_id"} =
          \"= nagios_hoststatus.host_object_id";
        $where->{"opsview_host_services.service_object_id"} =
          \"= nagios_servicestatus.service_object_id";
    }
    else {

        # This should not get here via controller (will delete this argument)
        die "summarizeon not specified" unless exists $args->{summarizeon};
        die "Invalid summarizeon: " . $args->{summarizeon};
    }

    # Add status stuff here. This is because the downtime calculations above do not require this table
    push @$tables, qw(nagios_servicestatus nagios_hoststatus);

    unless ( $args->{ignore_access} ) {
        if ( $args->{changeaccess} ) {
            if ( $contact_object && $contact_object->has_access("CHANGEALL") ) {

                # Do nothing, ie, return entire list
            }
            elsif ($contact_object
                && $contact_object->has_access("CHANGESOME") )
            {
                push @$tables, "opsview_contact_services";
                $where->{"opsview_contact_services.service_object_id"} =
                  \"= opsview_host_services.service_object_id";
                $where->{"opsview_contact_services.contactid"} =
                  $contact_object->id;
            }
            else {

                # No change access available, return an empty summary
                return $class->create_summarized_resultset(
                    $args->{summarizeon} );
            }
        }
        else {

            # Can use notification parameter to only list services that would get notified for this contact
            if ( $contact_object
                && ( !$contact_object->can_view_all || $args->{notifications} )
              )
            {
                push @$tables, "opsview_contact_services";
                $where->{"opsview_contact_services.service_object_id"} =
                  \"= opsview_host_services.service_object_id";
                $where->{"opsview_contact_services.contactid"} =
                  $contact_object->id;
            }
        }
    }

    # TODO: If you use filter values in HH, the links should preserve the filtering.
    # Also, these filters should appear earlier, before the call to downtimes
    $class->common_filters( $where, $args, $order_by );

    my $sql_abstract_table;
    if ( $args->{do_that_dirty_left_join_to_role_access_keywords} ) {
        my $t = join( " JOIN ", @$tables );

        # The roleid comparison is required to force only one row to get created
        $t
          .= " LEFT JOIN $opsview_db.role_access_keywords ON ( $opsview_db.keywords.id = $opsview_db.role_access_keywords.keywordid AND $opsview_db.role_access_keywords.roleid = "
          . $contact_object->role->id . ")";
        $sql_abstract_table = \$t;
    }
    else {
        $sql_abstract_table = $tables;
    }
    my ( $stmt, @bind ) =
      Utils::SQL::Abstract->new->select( $sql_abstract_table,
        $select, $where, $order_by, );
    my $sth = $dbh->prepare_cached($stmt);
    $sth->execute(@bind);
    return $class->create_summarized_resultset( $sth, $downtimes, $args );
}

# SQL returns back something like:
# hostgroup_name, hostgroup_id, host_object_id, host_state, host_unhandled, service_state, service_unhandled, total
# hostgroup133,   133,          7004,           0,          0,              3,             1,                 2
# hostgroup19,    19,           6428,           1,          1,              2,             0,                 3
# hostgroup19,    19,           6428,           1,          1,              3,             0,                 17
# hostgroup19,    19,           6609,           2,          1,              2,             0,                 2
# Use this to convert to our webservice response
sub create_summarized_resultset {
    my ( $class, $sth, $downtimes, $args ) = @_;
    my @list;
    my $group_key;
    my $group_label;
    my @extra_group_fields;
    if ( $args->{summarizeon} eq "hostgroup" ) {
        $group_key   = "hostgroup_id";
        $group_label = "hostgroup_name";
    }
    elsif ( $args->{summarizeon} eq "keyword" ) {
        $group_key = $group_label = "keyword_name";
        @extra_group_fields = qw(description);
    }
    my $last_group_label = "";
    my $last_group_key   = "";
    my $last_hash;
    my $found_hosts;
    my $status;
    my $summary = {
        host => {
            total     => 0,
            unhandled => 0
        },
        service => {
            total     => 0,
            unhandled => 0
        }
    };
    my $inner_sub = sub {
        $status->{name} = $last_group_label;
        $status->{$group_key} = $last_group_key
          unless ( $group_key eq $group_label );
        foreach my $field (@extra_group_fields) {
            $status->{$field} = $last_hash->{$field};
        }
        $status->{hosts}->{total} =
          $status->{hosts}->{handled} + $status->{hosts}->{unhandled};
        $status->{services}->{total} =
          $status->{services}->{handled} + $status->{services}->{unhandled};

        # Don't do this for the moment - causes test failures and I'm not convinced it buys you very much
        # at the expense of creating a larger transfer file
        #$status->{summary}->{handled}   = $status->{hosts}->{handled} + $status->{services}->{handled};
        #$status->{summary}->{unhandled} = $status->{hosts}->{unhandled} + $status->{services}->{unhandled};
        #$status->{summary}->{total}     = $status->{summary}->{handled} + $status->{summary}->{unhandled};
        set_highest_state($status);
        push @list, $status;
    };
    while ( my $hash = $sth->fetchrow_hashref ) {

        # Save hostgroup information on changes
        if ( $last_group_key ne $hash->{$group_key} ) {
            if ( $last_group_label ne "" ) {
                &$inner_sub;
            }
            $status = {
                hosts => {
                    handled   => 0,
                    unhandled => 0
                },
                services => {
                    handled   => 0,
                    unhandled => 0
                },
                downtime => $downtimes->{ $hash->{$group_key} }->{state},
            };
            $found_hosts      = {};
            $last_group_label = $hash->{$group_label};
            $last_group_key   = $hash->{$group_key};
            $last_hash        = $hash;
        }

        my $key;
        if ( !exists $found_hosts->{ $hash->{host_object_id} } ) {
            $found_hosts->{ $hash->{host_object_id} }++;
            $_ = convert_host_state_to_text( $hash->{host_state} );
            if ( $hash->{host_unhandled} ) {
                $status->{hosts}->{unhandled}++;
                $status->{hosts}->{$_}->{unhandled}++;
            }
            else {
                $status->{hosts}->{handled}++;
                $status->{hosts}->{$_}->{handled}++;
            }
            $summary->{host}->{$_}++;
            $summary->{host}->{unhandled}++ if $hash->{host_unhandled};
            $summary->{host}->{total}++;
        }
        $_ = convert_state_to_text( $hash->{service_state} );
        if ( $hash->{service_unhandled} ) {
            $status->{services}->{unhandled}       += $hash->{total};
            $status->{services}->{$_}->{unhandled} += $hash->{total};
            $summary->{service}->{unhandled}       += $hash->{total};
        }
        else {
            $status->{services}->{handled} += $hash->{total};
            $status->{services}->{$_}->{handled} += $hash->{total};
        }
        $summary->{service}->{$_} += $hash->{total};
        $summary->{service}->{total} += $hash->{total};
    }

    # Set the grouped information, needed if only one group retrieved
    if ($last_group_key) {
        &$inner_sub;
    }
    $summary->{host}->{handled} =
      $summary->{host}->{total} - $summary->{host}->{unhandled};
    $summary->{service}->{handled} =
      $summary->{service}->{total} - $summary->{service}->{unhandled};
    $summary->{unhandled} =
      $summary->{host}->{unhandled} + $summary->{service}->{unhandled};
    $summary->{handled} =
      $summary->{host}->{handled} + $summary->{service}->{handled};
    $summary->{total} =
      $summary->{host}->{total} + $summary->{service}->{total};
    return {
        list    => \@list,
        summary => $summary
    };
}

=item Runtime::Searches->convert_to_group_by_service( $services_hash )

Takes a list_services $services_hash and converts it so that it is service first

Format:
  {
   list => [
    {
    name => service name,
    summary => { ok => count, warning => c, critical => c, unknown => c, unhandled => c, handled => c, total => c },
    max_state => maximum state on all hosts,
    hosts => [
      { name => host name,
        state => service state on this host,
        output => service output,
        state_duration => seconds,
        acknowledged => 0,1,
        acknowledged_comment => text,
        acknowledged_author => acknowledged_by,
      },
      ... # More hosts
    },
    ... # More services
   ],
   summary => { ... }
  }

=cut

sub convert_to_group_by_service {
    my ( $class, $services_hash ) = @_;
    my @new_list           = ();
    my $services_lookup    = {};
    my $services_host_list = {};
    my $hosts_lookup       = {};

    # Reorder the hash of data to be service lead
    foreach my $host ( @{ $services_hash->{list} } ) {
        $hosts_lookup->{ $host->{name} } = $host;
        foreach my $service ( @{ $host->{services} } ) {
            if ( !exists $services_lookup->{ $service->{name} } ) {
                $services_lookup->{ $service->{name} } = $service;
                $_ = $services_host_list->{ $service->{name} } = [];
                push @new_list,
                  {
                    name  => $service->{name},
                    hosts => $_,
                  };
            }
            my $h = {
                name              => $host->{name},
                state             => $service->{state},
                output            => $service->{output},
                unhandled         => $service->{unhandled},
                state_duration    => $service->{state_duration},
                acknowledged      => $service->{acknowledged},
                markdown          => $service->{markdown},
                downtime          => $service->{downtime},
                service_object_id => $service->{service_object_id},
            };
            if ( $h->{downtime} ) {
                $h->{downtime_username} = $service->{downtime_username};
                $h->{downtime_comment}  = $service->{downtime_comment};
            }
            if ( $h->{acknowledged} ) {
                $h->{acknowledged_author}  = $service->{acknowledged_author};
                $h->{acknowledged_comment} = $service->{acknowledged_comment};
            }
            $h->{metrics} = $service->{metrics} if exists $service->{metrics};
            push @{ $services_host_list->{ $service->{name} } }, $h;
        }
    }

    # Calculate the summary information
    foreach my $service (@new_list) {
        my $summary        = {};
        my $max_state_text = "unknown";
        foreach my $host ( @{ $service->{hosts} } ) {
            $summary->{ $host->{state} }++;
            $summary->{ ( $host->{unhandled} == 1 ? "unhandled" : "handled" )
            }++;
            $summary->{total}++;
            $summary->{metrics} += scalar @{ $host->{metrics} }
              if exists $host->{metrics};
            $max_state_text =
              max_state_text( $max_state_text, $host->{state} );
        }
        $service->{max_state} = $max_state_text;
        $service->{summary}   = $summary;
    }
    return {
        list    => \@new_list,
        summary => $services_hash->{summary}
    };
}

=item count_services_by_keyword

Returns count of all services that this keyword will see based on the latest view

=cut

sub count_services_by_keyword {
    my ( $class, $keyword_object ) = @_;
    my ( $sql, $sth );
    my $dbh = $class->db_Main;

    $sql = "
select
 count(*)
from
 $runtime_db.opsview_viewports
where
 viewportid = ?
 AND host_object_id!=object_id
";
    return $dbh->selectrow_array( $sql, {}, $keyword_object->id );
}

=item $class->list_hosts_by_contact($contact, { q => "search_string" })

Lists all the hosts this contact can see. Returns a listref

=cut

sub list_hosts_by_contact {
    my ( $class, $contact, $params ) = @_;
    my $sql    = SQL::Abstract->new( cmp => "like" );
    my $tables = ["opsview_hosts"];
    my $where  = {
        -or => [
            "opsview_hosts.name"  => "%" . $params->{q} . "%",
            "opsview_hosts.ip"    => "%" . $params->{q} . "%",
            "opsview_hosts.alias" => "%" . $params->{q} . "%",
        ],
    };
    if ( $contact->can_view_all ) {
    }
    else {
        push @$tables, "opsview_contact_services cs",
          "opsview_host_services h2s";
        $where->{"cs.contactid"}          = $contact->id;
        $where->{"h2s.service_object_id"} = \"= cs.service_object_id";
        $where->{"opsview_hosts.id"}      = \"= h2s.host_object_id";
    }
    my ( $stmt, @bind ) = $sql->select(
        $tables,
        [
            "DISTINCT(opsview_hosts.name) as name",
            "opsview_hosts.icon_filename as icon",
            "opsview_hosts.ip as ip",
            "opsview_hosts.alias as alias",
        ],
        $where,
        ["name"],
    );
    my $hash = {};
    my $sth  = $class->db_Main->prepare_cached($stmt);
    $sth->execute(@bind);
    my $list = [];
    while ( @_ = $sth->fetchrow_array ) {
        push @$list,
          {
            name  => $_[0],
            icon  => $_[1],
            ip    => $_[2],
            alias => $_[3],
          };
    }
    return $list;
}

=item $class->list_rrd_objects({ type => "service", q => "search_string", contact => $contact, host => $arrayref })

Lists all the services this contact can see. In Opsview 2.14, this will query the db. In Opsview 3, this will look at the
rrd files.

=cut

sub list_rrd_objects {
    my ( $class, $params ) = @_;
    my $sql     = SQL::Abstract->new( cmp => "like" );
    my $tables  = ["opsview_host_services"];
    my $contact = $params->{contact};
    my $where =
      { "opsview_host_services.servicename" => "%" . $params->{q} . "%" };
    if ( $contact && !$contact->can_view_all ) {
        filter_by_contact_id( $tables, $where, $contact->id );
    }
    my ( $stmt, @bind ) =
      $sql->select( $tables,
        [ "DISTINCT(opsview_host_services.servicename) as name", ],
        $where, ["name"], );
    my $hash = {};
    my $sth  = $class->db_Main->prepare_cached($stmt);
    $sth->execute(@bind);
    my $list = [];
    while ( @_ = $sth->fetchrow_array ) {
        push @$list, { name => $_[0] };
    }
    return $list;
}

=item $class->list_comments

Returns a hash of all comments, keys by runtime object_id

=cut

sub list_comments {
    my ($class) = @_;
    my $hash = {};

    # Cannot use SQL::Abstract here it doesn't cater for GROUP BY
    my $sql = qq{
	SELECT object_id, COUNT(comment_id) AS count
	FROM nagios_comments
	GROUP BY object_id
	};
    my $sth = $class->db_Main->prepare_cached($sql);
    $sth->execute();

    while ( my @id = $sth->fetchrow_array ) {
        $hash->{ $id[0] } = $id[1];
    }
    return $hash;
}

sub as_hashref {
    my $self = shift;
    my %hash = %{$self};
    return \%hash;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
