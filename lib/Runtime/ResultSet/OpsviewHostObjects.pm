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

package Runtime::ResultSet::OpsviewHostObjects;

use strict;
use warnings;

use Opsview::Utils
  qw(convert_to_arrayref convert_state_to_text convert_host_state_to_text convert_state_type_to_text set_highest_service_state get_first_hash_key convert_uoms);

use base qw/Runtime::ResultSet/;

use Opsview::Performanceparsing;
Opsview::Performanceparsing->init;

# This handles all the filtering, based on parameters coming in
sub filter_objects {
    my ( $self, $filters, $args ) = @_;

    my $num_filters    = 0;
    my $service_search = 0;

    # Host groups
    my @hostgroupids;
    if ( exists $filters->{hostgroupid} ) {
        $_            = convert_to_arrayref( $filters->{hostgroupid} );
        @hostgroupids = @$_;
    }
    if ( exists $filters->{hostgroupname} ) {
        my $hostgroupnames = convert_to_arrayref( $filters->{hostgroupname} );
        my $hg_rs =
          $self->result_source->schema->resultset( "OpsviewHostgroups" );
        foreach my $hgname (@$hostgroupnames) {
            my @found =
              map { $_->id } ( $hg_rs->search( { name => $hostgroupnames } ) );
            if (@found) {
                push @hostgroupids, @found;
            }
        }
    }
    if (@hostgroupids) {
        $self = $self->search(
            { "hostgroups.hostgroup_id" => \@hostgroupids },
            { join                      => "hostgroups" }
        );
        $num_filters++;
    }

    # Host names
    my $hostnames = get_first_hash_key( $filters, "hostname", "host" );
    if ( defined $hostnames ) {
        $self =
          $self->search( { "me.hostname" => { "-like" => $hostnames } } );
        $num_filters++;
    }
    if ( exists $filters->{hostid} ) {
        $self = $self->search( { "me.host_object_id" => $filters->{hostid} } );
        $num_filters++;
    }

    # Service names
    my $servicenames =
      get_first_hash_key( $filters, "servicename", "servicecheck" );
    if ( defined $servicenames ) {
        $self =
          $self->search( { "me.name2" => { "-like" => $servicenames } } );
        $num_filters++;
        $service_search++;
    }
    if ( exists $filters->{serviceid} ) {
        $self = $self->search( { "me.object_id" => $filters->{serviceid} } );
        $num_filters++;
        $service_search++;
    }
    if ( exists $filters->{hs} ) {
        my $hostservicenames = convert_to_arrayref( $filters->{hs} );
        my @search_list;
        foreach my $hs (@$hostservicenames) {
            my ( $hostname, $servicename ) = split( "::", $hs );
            next unless ( defined $hostname && defined $servicename );
            push @search_list,
              {
                "me.hostname" => $hostname,
                "me.name2"    => $servicename
              };
        }
        if (@search_list) {
            $self = $self->search( { "-or" => \@search_list } );
            $num_filters++;
            $service_search++;
        }
    }

    # Other stuff
    if ( exists $filters->{keyword} ) {
        $self = $self->search(
            { "viewports.keyword" => $filters->{keyword} },
            { join                => "viewports" }
        );
        $num_filters++;
        $service_search++;
    }

    if ( exists $filters->{monitoredby} ) {
        $self = $self->search(
            { "host.monitored_by" => $filters->{monitoredby} },
            { join                => "host" }
        );
        $num_filters++;
    }

    # If inclusive, then make search fail to return any objects if no filtering is applied
    if ( $args->{inclusive} && $num_filters == 0 ) {
        $self = $self->search( { 1 => 0 } );
    }

    # smart_object_search means that if there are filtering parameters for services, then
    # service objects are returned, otherwise host objects are returned
    if ( $args->{smart_object_search} ) {
        if ($service_search) {
            $self = $self->search_only_services;
        }
        else {
            $self = $self->search_only_hosts;
        }
    }
    $self;
}

# This should not be used. Instead, you should search objects based on /rest/runtime/service?group_by=host&distinct=1

=begin comment

sub list_host_objects {
    my ( $self, $filters, $args ) = @_;
    $args ||= {};

    my $total = $self->search_only_hosts->count;
    $self = $self->search(
        {},
        {   "select"   => [ \"DISTINCT(me.host_object_id)", "hostname" ],
            "as"       => [ "id",                           "hostname" ],
            "order_by" => ["hostname"],
        }
    );

    $self = $self->filter_objects($filters);
    my $allrows = $self->count;

    my $opts = {};
    my $rows = ( exists $filters->{rows} ) ? $filters->{rows} : 50;
    if ( !( $rows eq "all" || $rows == 0 ) ) {
        $opts->{rows} = $rows;
        $opts->{page} = $filters->{page} || 1;
    }
    $self = $self->search( {}, $opts );

    my @list = map { $_->hostname } $self->all;
    return {
        list    => \@list,
        rows    => scalar @list,
        allrows => $allrows,
        total   => $total,
    };
}

=cut

my $lookup_groupings = {
    "host" => {
        order_by    => [ "hostname", "name2" ],
        group_key   => "hostname",
        collect_key => "name2",
    },
    "service" => {
        order_by    => [ "name2", "hostname" ],
        group_key   => "name2",
        collect_key => "hostname",
    },
};

sub list_service_objects {
    my ( $self, $filters, $args ) = @_;
    $args ||= {};

    $self = $self->search_only_services;

    my $group_by = "host";
    if ( ( $filters->{group_by} || "" ) eq "service" ) {
        $group_by = "service";
    }

    # When searching this table, there's 4 different cases:
    #   * list me all distinct hosts based on searching services/keywords/hostgroups
    #   * list me all distinct service names
    #   * list me all services, grouped by host
    #   * list me all services, grouped by service
    # These options below try to cater for all these use cases
    my $distinct = $filters->{distinct} || 0;
    my $opts = { result_class => "DBIx::Class::ResultClass::HashRefInflator", };
    if ($distinct) {
        $opts->{distinct} = 1;
        $opts->{select}   = [ $lookup_groupings->{$group_by}->{group_key} ];
        $opts->{as}       = [ $lookup_groupings->{$group_by}->{group_key} ];
        $opts->{order_by} = [ $lookup_groupings->{$group_by}->{group_key} ];
    }
    else {
        $opts->{select} = [ "hostname", "name2" ];
        $opts->{as}     = [ "hostname", "name2" ];
        $opts->{order_by} = $lookup_groupings->{$group_by}->{order_by};
    }

    $self = $self->search( {}, $opts, );
    my $total = $self->count;

    $self = $self->filter_objects($filters);
    my $allrows = $self->count;

    my $paging_opts = {};
    my $rows = ( exists $filters->{rows} ) ? $filters->{rows} : 50;
    if ( !( $rows eq "all" || $rows == 0 ) ) {
        $paging_opts->{rows} = $rows;
        $paging_opts->{page} = $filters->{page} || 1;
    }
    $self = $self->search( {}, $paging_opts );

    my @list = ();
    my $last = "";
    my $object;
    my $groupkey    = $lookup_groupings->{$group_by}->{group_key};
    my $collect_key = $lookup_groupings->{$group_by}->{collect_key};
    my $groupings;
    my $new_group_sub = sub {
        $object->{name} = $last;
        $object->{list} = $groupings unless $distinct;
        push @list, $object;
        $object    = {};
        $groupings = [];
    };
    while ( my $row = $self->next ) {
        if ( $last ne $row->{$groupkey} ) {
            if ( $last ne "" ) {
                $new_group_sub->();
            }
            $last = $row->{$groupkey};
        }
        push @$groupings, $row->{$collect_key};
    }
    if ($last) {
        $new_group_sub->();
    }

    return {
        list    => \@list,
        rows    => $self->count,
        allrows => $allrows,
        total   => $total,
    };
}

sub list_summary {
    my ( $self, $filters, $args ) = @_;
    $args ||= {};

    $self = $self->filter_objects($filters);

    # Need to make distinct because viewports may request same item multiple times
    # Can't use DBIx::Class' distinct because it groups by all fields which include calculated ones
    # So use mysql's DISTINCT, but this needs to be the first item in SELECT
    $self = $self->search(
        {},
        {
            "select" => [ \"DISTINCT(me.object_id)", ],
            "as"     => ["id"],
        }
    );

    $args->{comments_hash} = $self->_comments_hash( "me.object_id" );

    $self->next::method( $filters, $args );
}

sub _downtimes_hash {
    my ( $self, $key ) = @_;
    $self = $self->search( {}, { join => "downtimes" } );
    $self->next::method( "me.object_id" );
}

sub _comments_hash {
    my ( $self, $key ) = @_;
    $self = $self->search( {}, { join => "comments" } );
    $self->next::method($key);
}

sub search_only_services {
    my $self =
      shift->search( { "me.host_object_id" => { "!=" => \"me.object_id" } } );
    $self;
}

sub search_only_hosts {
    my $self =
      shift->search( { "me.host_object_id" => { "=" => \"me.object_id" } } );
    $self;
}

sub create_summarized_resultset {
    my ( $self, $downtimes, $filters, $args ) = @_;

    my $comments = $args->{comments_hash};

    # Restrict to services - take out later to see if it is necessary
    $self = $self->search_only_services;

    # Specific info to get
    # Need DISTINCT because filter by keywords could list same item multiple times
    #<<<
    $self = $self->search( {},
        {
            "+select" => [
                "me.host_object_id",
                "me.hostname AS host",
                "host.alias",
                "host.icon_filename",
                "hoststatus.is_flapping",
                "hoststatus.problem_has_been_acknowledged",
                "host.num_interfaces",
                "host.num_services",
                "hoststatus.output",
                "hoststatus.current_check_attempt",
                "hoststatus.max_check_attempts",
                "hoststatus.state_type",
                \"UNIX_TIMESTAMP(hoststatus.last_check)",
                \"UNIX_TIMESTAMP(hoststatus.last_state_change)",
                "me.object_id",
                "me.name2 AS service",
                "servicestatus.is_flapping",
                "servicestatus.problem_has_been_acknowledged",
                "servicestatus.output",
                "servicestatus.perfdata",
                "servicestatus.state_type",
                "me.perfdata_available",
                "me.markdown_filter",
                "servicestatus.current_check_attempt",
                "servicestatus.max_check_attempts",
                \"UNIX_TIMESTAMP(servicestatus.last_check)",
                \"UNIX_TIMESTAMP(servicestatus.last_state_change) AS last_state_change_timev",
            ],
            "+as" => [
                "host_object_id",
                "host",
                "alias",
                "icon",
                "host_flapping",
                "host_acknowledged",
                "num_interfaces",
                "num_services",
                "host_output",
                "host_current_check_attempt",
                "host_max_check_attempts",
                "host_state_type",
                "host_last_check_timev",
                "host_last_state_change_timev",
                "service_object_id",
                "service",
                "service_flapping",
                "service_acknowledged",
                "service_output",
                "service_perfdata",
                "service_state_type",
                "perfdata_available",
                "markdown_filter",
                "current_check_attempt",
                "max_check_attempts",
                "last_check_timev",
                "last_state_change_timev",
            ],
            "join" => [ "host", "hoststatus", "servicestatus" ],
        }
    );
    #>>>

    # Move this lower because will check for downtimes further up
    if (   exists $filters->{downtime_start_time}
        && exists $filters->{downtime_comment} )
    {

        # Logic used to be that if a host was in downtime, all the services are also in downtime
        # This was because it was possible in Nagios to only set a host in downtime.
        # However, Opsview UI host downtime will sets all services to be in downtime too
        # So for purposes of listing services, we only list the services which have an associated
        # downtime entry, rather than try to see if hosts are also in downtime
        $self = $self->search(
            {
                "downtimes.scheduled_start_time" =>
                  $filters->{downtime_start_time},
                "downtimes.comment_data" => $filters->{downtime_comment},
            },
            { join => "downtimes" }
        );
    }

    # Add ordering
    my $order_by = [ "host", "service" ];
    if ( exists $filters->{order} ) {
        my %valid_orderbys = (
            state => [ "service_state_priority", "host", "service" ],
            state_desc =>
              [ { "-desc" => "service_state_priority" }, "host", "service" ],
            service                => "service",
            service_desc           => { "-desc" => "service" },
            host                   => "host",
            host_desc              => { "-desc" => "host" },
            host_state             => "host_state",
            host_state_desc        => { "-desc" => "host_state" },
            last_check             => "last_check_timev",
            last_check_desc        => { "-desc" => "last_check" },
            last_state_change      => "last_state_change_timev",
            last_state_change_desc => { "-desc" => "last_state_change_timev" },
        );

        # Need to add an extra select column if these orderbys are specified
        my %add_select = (
            state      => 1,
            state_desc => 1
        );
        my $flag = 0;
        $_        = convert_to_arrayref( $filters->{order} );
        $order_by = [
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
              "IF(servicestatus.current_state=3, 0.5, servicestatus.current_state)";
            if ( $filters->{includeunhandledhosts} ) {
                $service_reordering =
                  "IF(hoststatus.current_state=0, $service_reordering, hoststatus.current_state*10)";
            }
            $self = $self->search(
                {},
                {
                    "+select" =>
                      [ "$service_reordering AS service_state_priority", ],
                    "+as" => [ "service_state_priority", ],
                }
            );
        }
    }
    $self = $self->search( {}, { order_by => $order_by } );

    if ( $filters->{includeperfdata} ) {
        $self = $self->search(
            {},
            {
                "+select" => ["performance_metrics.metricname"],
                "+as"     => ["metricname"],
                "join"    => "performance_metrics"
            }
        );
    }

    # Use this to convert to our webservice response
    my @list;
    my @extra_group_fields = qw(icon alias);

    my $now              = time();
    my $seen_hosts       = {};
    my $last_group_label = "";
    my $last_group_key   = "";
    my $last_hash;
    my $found_hosts;
    my $status;
    my $this_host;
    my $this_service;
    my $last_host = "";
    my $services_list;
    my $service_metrics         = [];
    my $service_metrics_by_name = {};
    my $summary                 = {
        host => {
            total     => 0,
            unhandled => 0
        },
        service => {
            total     => 0,
            unhandled => 0
        }
    };
    my $last_service_object_id = 0;
    my $finish_host            = sub {
        $this_host->{summary}->{total} =
          $this_host->{summary}->{handled} + $this_host->{summary}->{unhandled};
        set_highest_service_state( $this_host->{summary} );
        $this_host->{services} = $services_list;

        $summary->{service}->{handled}   += $this_host->{summary}->{handled};
        $summary->{service}->{unhandled} += $this_host->{summary}->{unhandled};

        push @list, $this_host;
        $services_list = [];
    };
    while ( my $hash = $self->next ) {

        # Save host information on changes
        if ( $last_host ne $hash->{host} ) {
            if ( $last_host ne "" ) {
                $finish_host->();
            }

            # Initialise
            $last_host = $hash->{host};
            $this_host = {
                summary => {
                    handled   => 0,
                    unhandled => 0
                },
                downtime => $downtimes->{ $hash->{id} }->{state} || 0,
                name     => $hash->{host},
                alias    => $hash->{alias},
                icon     => $hash->{icon},
                state     => convert_host_state_to_text( $hash->{host_state} ),
                unhandled => $hash->{host_unhandled},
            };

            $this_host->{flapping}     = 1 if $hash->{host_flapping};
            $this_host->{acknowledged} = 1 if $hash->{host_acknowledged};
            $this_host->{comments} = $comments->{ $hash->{host_object_id} }
              if exists $comments->{ $hash->{host_object_id} };
            $this_host->{last_check} =
              DateTime->from_epoch( epoch => $hash->{host_last_check_timev} );
            $this_host->{current_check_attempt} =
              $hash->{host_current_check_attempt};
            $this_host->{max_check_attempts} = $hash->{host_max_check_attempts};
            $this_host->{state_duration} =
              $now - $hash->{host_last_state_change_timev};
            $this_host->{state_type} =
              convert_state_type_to_text( $hash->{host_state_type} );
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

            unless ( exists $seen_hosts->{$last_host} ) {
                $seen_hosts->{$last_host}++;
                $summary->{host}
                  ->{ convert_host_state_to_text( $hash->{host_state} ) }++;
                $summary->{host}->{unhandled}++ if $hash->{host_unhandled};
                $summary->{host}->{total}++;
            }
        }

        $this_service = {
            name              => $hash->{service},
            service_object_id => $hash->{service_object_id},
            state     => convert_state_to_text( $hash->{service_state} ),
            output    => $hash->{service_output},
            unhandled => $hash->{service_unhandled},
            perfdata_available    => $hash->{perfdata_available},
            markdown              => $hash->{markdown_filter},
            current_check_attempt => $hash->{current_check_attempt},
            max_check_attempts    => $hash->{max_check_attempts},
            last_check =>
              DateTime->from_epoch( epoch => $hash->{last_check_timev} ),
            state_duration => $now - $hash->{last_state_change_timev},
            state_type =>
              convert_state_type_to_text( $hash->{service_state_type} ),
        };

        $this_service->{flapping} = 1 if $hash->{service_flapping};
        $this_service->{comments} = $comments->{ $hash->{service_object_id} }
          if exists $comments->{ $hash->{service_object_id} };

        if ( $filters->{includeperfdata} ) {

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
                    my $value = $p->value;

                    next if ( $value eq "U" );

                    my $uom = $p->uom;

                    if ( $filters->{convertuom} ) {
                        my ( $uom_new, $uom_multiplier ) = convert_uoms($uom);
                        $uom = $uom_new;
                        $value *= $uom_multiplier;
                    }

                    my $h = {
                        name  => $p->label,
                        uom   => $uom,
                        value => $value,
                    };

                    push @$service_metrics, $h;
                    $service_metrics_by_name->{ $h->{name} } = $h;
                }
                $this_service->{metrics} = $service_metrics;
            }
            if ( !exists $service_metrics_by_name->{ $hash->{metricname} } ) {
                push @$service_metrics, { name => $hash->{metricname} };
            }
            if ( !$first_metric_for_service ) {

                # Can ignore rest because service should be exactly the same as prior rows
                next;
            }
        }
        if ( $hash->{service_acknowledged} ) {
            $this_service->{acknowledged} = 1;

            if ( exists $filters->{includehandleddetails} ) {
                my $ack = $self->result_source->schema->resultset(
                    "NagiosAcknowledgements")->search(
                    { object_id => $hash->{service_object_id} },
                    { order_by  => { "-desc" => "entry_time" } }
                    )->first;
                $this_service->{acknowledged_author} =
                  $ack ? $ack->author_name : undef;
                $this_service->{acknowledged_comment} =
                  $ack ? $ack->comment_data : undef;
            }

        }

        # Downtime calculation. Work out whether host or service is higher state, then use username and comment from there
        my $sdt = $downtimes->{ $hash->{service_object_id} };
        if ( ( $sdt->{state} || 0 ) < ( $this_host->{downtime} || 0 ) ) {
            map { $this_service->{$_} = $this_host->{$_} }
              qw(downtime downtime_username downtime_comment);
        }
        elsif ( $sdt->{state} ) {
            $this_service->{downtime}          = $sdt->{state};
            $this_service->{downtime_username} = $sdt->{username};
            $this_service->{downtime_comment}  = $sdt->{comment};
        }
        else {
            $this_service->{downtime} = 0;
        }

        push @$services_list, $this_service;

        my $key;
        if ( $hash->{service_unhandled} ) {
            $key = "unhandled";
        }
        else {
            $key = "handled";
        }
        $this_host->{summary}->{$key}++;
        $this_host->{summary}->{ $this_service->{state} }++;
        $summary->{service}->{ $this_service->{state} }++;
        $summary->{service}->{total}++;
    }

    # Set the grouped information, needed if only one group retrieved
    if ($last_host) {
        $finish_host->();
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

    my $response = { summary => $summary };
    if ( ( defined $filters->{rows} ? $filters->{rows} : "" ) ne "0" ) {
        $response->{list} = \@list;
    }
    return $response;

    # Don't call next
    #$self->next::method( $downtimes, $args );
}

# Lists all the downtimes according to Runtime database
# Groups the downtimes together based on scheduled_start_time, scheduled_end_time, author and comment
# Heavy on magic in this area!
# Returns an object in the form:
#{ summary => {
#    rows => ....
#    totalrows => ....
#    allrows => ....
#    page => ....
#    totalpages => ....
#    num_hosts => ....
#    num_services => ....
#  },
#  list => [
#    { started => 0,1,  # 0=not started yet, 1=started
#      start_time => ...., # if started, actual start time, else scheduled start time
#      scheduled_end_time => .....,
#      comment => .....,
#      author => .....,
#      objects => {
#        hosts => [
#          { hostname => ...., id => ... },
#        ],
#        services => [
#          { id => ...., hostname => ...., servicename => .... },
#        ],
#      }
#    },
#    ...
#  ]
#}
sub list_downtimes {
    my ( $self, $filters ) = @_;

    my $last_scheduled_start_time = "";
    my $last_scheduled_end_time   = "";
    my $last_comment_data         = "";
    my $last_author_name          = "";
    my $opts                      = {
        order_by => [
            "scheduled_start_time", "scheduled_end_time",
            "comment_data",         "author_name"
        ],
    };

    my $rows = ( exists $filters->{rows} ) ? $filters->{rows} : 50;
    if ( !( $rows eq "all" || $rows == 0 ) ) {
        $opts->{rows} = $rows;
        $opts->{page} = $filters->{page} || 1;
    }

    # Take copy as $rs will get switched later
    my $rs = $self;

    $rs = $rs->filter_objects($filters);

    # Switch to looking at downtimes
    $rs = $rs->search_related( "downtimes", {}, $opts );

    my @results;
    my $objects;
    my $this_downtime;
    my $num_hosts    = 0;
    my $num_services = 0;
    while ( my $it = $rs->next ) {
        if (
            !(
                   $last_scheduled_start_time eq $it->scheduled_start_time
                && $last_comment_data         eq $it->comment_data
                && $last_scheduled_end_time   eq $it->scheduled_end_time
                && $last_author_name          eq $it->author_name
            )
          )
        {
            if ($this_downtime) {
                $this_downtime->{objects} = $objects;
                push @results, $this_downtime if $rows ne "0";
                $objects = {};
            }
            $this_downtime = {
                comment            => $it->comment_data,
                author             => $it->author_name,
                started            => $it->was_started,
                scheduled_end_time => $it->scheduled_end_time,
                start_time         => $it->scheduled_start_time,
            };
            if ( $it->was_started ) {
                $this_downtime->{actual_start_time} = $it->actual_start_time;
            }

            $last_scheduled_start_time = $it->scheduled_start_time;
            $last_scheduled_end_time   = $it->scheduled_end_time;
            $last_author_name          = $it->author_name;
            $last_comment_data         = $it->comment_data;
        }
        if ( !defined $it->object->name2 ) {
            push @{ $objects->{hosts} },
              {
                hostname => $it->object->hostname,
                id       => $it->object_id
              };
            $num_hosts++;
        }
        else {
            push @{ $objects->{services} },
              {
                hostname    => $it->object->hostname,
                servicename => $it->object->name2,
                id          => $it->object_id
              };
            $num_services++;
        }
    }
    if ($this_downtime) {
        $this_downtime->{objects} = $objects;
        push @results, $this_downtime if $rows ne "0";
    }
    my $summary = {
        num_hosts    => $num_hosts,
        num_services => $num_services,
        rows         => $rs->count,
        allrows      => $self->related_resultset("downtimes")->count,
    };
    if ( !( $rows eq "all" || $rows eq "0" ) ) {
        $summary->{totalrows}  = $rs->pager->total_entries;
        $summary->{totalpages} = $rs->pager->last_page;
        $summary->{page}       = $rs->pager->current_page;
    }
    my $response = { summary => $summary };
    if ( !defined( $filters->{rows} ) || $filters->{rows} ne "0" ) {
        $response->{list} = \@results;
    }
    return $response;
}

# Compatibility layer for object_info_base, which expects Class::DBI-isms
sub retrieve {
    shift->find(@_);
}

sub restrict_by_user {
    my ( $rs, $user ) = @_;
    $rs = $rs->search(
        { "contacts.contactid" => $user->id },
        { join                 => 'contacts' },
    );
    return $rs;
}

1;
