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

package Runtime::ResultSet;

use strict;
use warnings;

use base qw/DBIx::Class::ResultSet/;

use Opsview::Utils
  qw(convert_to_arrayref convert_host_state_to_text convert_state_to_text
  set_highest_state max_state);

my $state_type_lookup = {
    "soft" => 0,
    "0"    => 0,
    "hard" => 1,
    "1"    => 1,
};

# critical, warning, uknown, ok, ?
my $default_unhandled_order = [ 2, 1, 3, 0, 4 ];

sub list_summary {
    my ( $self, $filters, $args ) = @_;

    $filters ||= {};
    $args    ||= {};

    # Optional columns
    my $cols = convert_to_arrayref( $filters->{cols} );
    my @requested_columns = map { split( ",", $_ ) } @$cols;
    my %extracols  = map { ( $_ => 1 ) } @{ $args->{extra_columns} || [] };
    my %removecols = ();
    foreach my $col (@requested_columns) {
        if ( $col =~ s/^-// ) {
            $removecols{$col} = 1;
        }
    }
    foreach my $remove ( keys %removecols ) {
        delete $extracols{$remove};
    }

    # Get downtime information - this needs to be overridden to do the appropriate join and set the key
    my $downtimes = $self->_downtimes_hash( "badkey" );

    my $opts = {};
    my $rows = ( exists $filters->{rows} ) ? $filters->{rows} : "all";
    if ( !( $rows eq "all" || $rows == 0 ) ) {
        $opts->{rows} = $rows;
        $opts->{page} = $filters->{page} || 1;
    }

    $self = $self->search( {}, $opts );

    # Join to status information
    if ( $filters->{filter} ) {
        if ( $filters->{filter} eq "handled" ) {
            if ( exists $filters->{includeunhandledhosts} ) {
                $self = $self->search(
                    {},
                    {
                        having => {
                            "service_unhandled" => 0,
                            "host_unhandled"    => 1,
                            "service_state"     => { "!=" => 0 }
                        }
                    }
                );
            }
            else {
                $self =
                  $self->search( {}, { having => { "service_unhandled" => 0 } }
                  );
            }

        }
        elsif ( $filters->{filter} eq "unhandled" ) {
            if ( exists $filters->{includeunhandledhosts} ) {
                $self = $self->search(
                    {},
                    {
                        having => [
                            { "service_unhandled" => 1 },
                            {
                                "host_unhandled" => 1,
                                "service_state"  => { "!=" => 0 }
                            }
                        ]
                    }
                );
            }
            else {
                $self =
                  $self->search( {}, { having => { "service_unhandled" => 1 } }
                  );
            }
        }
    }
    if ( exists $filters->{host_filter} ) {
        if ( $filters->{host_filter} eq "handled" ) {
            $self = $self->search( {}, { having => { host_unhandled => 0 } } );
        }
        elsif ( $filters->{host_filter} eq "unhandled" ) {
            $self = $self->search( {}, { having => { host_unhandled => 1 } } );
        }
    }
    $self =
      $self->search( { "servicestatus.current_state" => $filters->{state} } )
      if ( exists $filters->{state} );
    $self =
      $self->search( { "hoststatus.current_state" => $filters->{host_state} } )
      if ( exists $filters->{host_state} );

    if ( exists $filters->{state_type} ) {
        my $state_type_list = convert_to_arrayref( $filters->{state_type} );
        my @search_params   = map {
            exists $state_type_lookup->{$_}
              ? $state_type_lookup->{$_}
              : ()
        } @$state_type_list;
        $self =
          $self->search( { "servicestatus.state_type" => \@search_params } );
    }

    if ( exists $filters->{host_state_type} ) {
        my $state_type_list =
          convert_to_arrayref( $filters->{host_state_type} );
        my @search_params = map {
            exists $state_type_lookup->{$_}
              ? $state_type_lookup->{$_}
              : ()
        } @$state_type_list;
        $self =
          $self->search( { "hoststatus.state_type" => \@search_params } );
    }

    #<<<
    $self = $self->search(
        {},
        {
            '+select' => [
                \'UNIX_TIMESTAMP(hoststatus.last_state_change)',
                \'UNIX_TIMESTAMP(hoststatus.last_notification)',
                'hoststatus.current_notification_number',
                'hoststatus.flap_detection_enabled',
            ],
            '+as' => [
                'last_state_change',           'last_notification',
                'current_notification_number', 'flap_detection_enabled',
            ],
        }
    ) if $filters->{includeextradetails};

    # Standard information to get.
    # host_unhandled is if host state is DOWN and not ack nor downtime
    # service_unhandled is if host is UP
    $self = $self->search( {},
        {
        "+select" => [
            "hoststatus.current_state AS host_state",
            "(hoststatus.current_state = 1 AND hoststatus.problem_has_been_acknowledged != 1 AND hoststatus.scheduled_downtime_depth = 0) AS host_unhandled",
            "servicestatus.current_state AS service_state",
            "(servicestatus.current_state != 0 AND hoststatus.current_state = 0 AND servicestatus.problem_has_been_acknowledged!=1 AND servicestatus.scheduled_downtime_depth=0) AS service_unhandled",
            ],
        "+as" => [
            "host_state",
            "host_unhandled",
            "service_state",
            "service_unhandled",
            ],
        result_class => "DBIx::Class::ResultClass::HashRefInflator",
        }
    );
    #>>>
    # Create hash
    $filters->{extra_columns} = \%extracols;
    return $self->create_summarized_resultset( $downtimes, $filters, $args );
}

# SQL returns back something like:
# hostgroup_name, hostgroupid,  host_object_id, host_state, host_unhandled, service_state, service_unhandled, total
# hostgroup133,   133,          7004,           0,          0,              3,             1,                 2
# hostgroup19,    19,           6428,           1,          1,              2,             0,                 3
# hostgroup19,    19,           6428,           1,          1,              3,             0,                 17
# hostgroup19,    19,           6609,           2,          1,              2,             0,                 2
# Use this to convert to our webservice response
sub create_summarized_resultset {
    my ( $self, $downtimes, $filters, $args ) = @_;
    my @extra_columns = keys %{ $filters->{extra_columns} || {} };
    my @list;
    my $group_key;
    my $group_label;
    my @extra_group_fields;
    if ( $filters->{summarizeon} eq "hostgroup" ) {
        $group_key          = "hostgroupid";
        $group_label        = "hostgroup_name";
        @extra_group_fields = qw(hostgroupid);
    }
    elsif ( $filters->{summarizeon} eq "keyword" ) {
        $group_key = $group_label = "keyword_name";
        @extra_group_fields = qw(description exclude_handled);
    }
    my $last_group_label = "";
    my $last_group_key   = "";
    my $last_hash;
    my $found_hosts;
    my $highest_host_unhandled_state    = 0;
    my $highest_service_unhandled_state = 0;
    my $uses_exclude_handled            = 0;
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
    my $servicegroups_lookup;
    my $inner_sub = sub {
        $status->{name} = $last_group_label;
        $status->{$group_key} = $last_group_key
          unless ( $group_key eq $group_label );
        foreach my $field ( @extra_group_fields, @extra_columns ) {

            if ( $field eq "matpath" ) {
                my @names = split( ",", $last_hash->{matpath} );
                pop @names; # Last one is blank
                my @ids = split( ",", $last_hash->{matpathid} );
                my @matpath;
                foreach my $name (@names) {
                    push @matpath,
                      {
                        id   => shift @ids,
                        name => $name
                      };
                }
                $status->{$field} = \@matpath;
            }
            else {
                $status->{$field} = $last_hash->{$field};
            }
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

        if ( $args->{viewport_check_exclude_handled} && $uses_exclude_handled )
        {
            $status->{computed_state} = convert_state_to_text(
                max_state(
                    $highest_host_unhandled_state,
                    $highest_service_unhandled_state,
                    $default_unhandled_order
                )
            );
            $status->{services}->{computed_state} =
              convert_state_to_text($highest_service_unhandled_state);
        }
        else {
            set_highest_state($status);
        }

        push @list, $status;
    };
    while ( my $hash = $self->next ) {

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
            $found_hosts                     = {};
            $last_group_label                = $hash->{$group_label};
            $last_group_key                  = $hash->{$group_key};
            $last_hash                       = $hash;
            $highest_host_unhandled_state    = 0;
            $highest_service_unhandled_state = 0;
            $uses_exclude_handled            = 0;
        }

        $uses_exclude_handled = $hash->{exclude_handled};

        if ( $args->{viewport_check_exclude_handled} && $uses_exclude_handled )
        {
            $highest_host_unhandled_state =
              max_host_unhandled_state( $highest_host_unhandled_state, $hash )
              if $hash->{host_unhandled};

            $highest_service_unhandled_state =
              max_service_unhandled_state( $highest_service_unhandled_state,
                $hash )
              if $hash->{service_unhandled};
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

        if ( $filters->{include_servicegroups} ) {
            $status->{servicegroups}->{ $hash->{servicegroup_name} }->{$_}
              += $hash->{total};
            $servicegroups_lookup->{ $hash->{servicegroup_name} } = 1;
        }
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
    if ( exists $args->{totalhgs} ) {
        $summary->{totalhgs} = $args->{totalhgs};
    }

    my $reply = {
        list    => \@list,
        summary => $summary
    };

    if ( $filters->{include_servicegroups} ) {
        my $servicegroup_list =
          [ map { { name => $_ } } sort keys %$servicegroups_lookup ];
        $reply->{servicegroups} = $servicegroup_list;
    }

    return $reply;
}

sub max_host_unhandled_state {
    my ( $current_max, $hash ) = @_;

    # host is not ok - set to critical
    return max_state( $current_max, 2, $default_unhandled_order )
      if $hash->{host_state} > 0;

    return max_state( $current_max, $hash->{host_state},
        $default_unhandled_order );
}

sub max_service_unhandled_state {
    my ( $current_max, $hash ) = @_;

    # return new max
    return max_state( $current_max, $hash->{service_state},
        $default_unhandled_order );
}

# We run downtimes separately because there could be lots of downtime for each
# object, which makes other queries grow exponentially
# We group results based on the incoming key
# As there could be more than 1 downtime for the key, we take order by
#  * was_started
#  * 1st downtime comment
sub _downtimes_hash {
    my ( $self, $key_column ) = @_;

    my $rs = $self->search(
        {},
        {
            "select" => [
                $key_column,             "downtimes.was_started",
                "downtimes.author_name", "downtimes.comment_data",
            ],
            "as" => [ "key", "started", "username", "comment", ],
            "order_by"   => ["downtimes.scheduled_start_time"],
            result_class => "DBIx::Class::ResultClass::HashRefInflator",
        }
    );

    my $result = {};
    while ( my $hash = $rs->next ) {
        my $key = $hash->{key};
        if ( $hash->{started} ) {
            if ( !$result->{$key} || $result->{$key}->{state} < 2 ) {
                $result->{$key} = {
                    state    => 2,
                    username => $hash->{username},
                    comment  => $hash->{comment},
                };
            }
        }
        else {
            if ( !$result->{$key} || $result->{$key}->{state} < 1 ) {
                $result->{$key} = {
                    state    => 1,
                    username => $hash->{username},
                    comment  => $hash->{comment},
                };
            }
        }
    }
    return $result;
}

# We track comments separately for same reasons as downtime
sub _comments_hash {
    my ( $self, $key_column ) = @_;

    my $rs = $self->search(
        {},
        {
            "select"   => [ $key_column, \"COUNT(*)", ],
            "as"       => [ "key",       "num_comments", ],
            "group_by" => $key_column,
            result_class => "DBIx::Class::ResultClass::HashRefInflator",
        }
    );

    my $result = {};
    while ( my $hash = $rs->next ) {
        my $key = $hash->{key};
        $result->{$key} = $hash->{num_comments};
    }
    return $result;
}

# This should be overridden by the subclass to apply
# restrictions based on the user object. This gives an error
# if that doesn't happen
sub restrict_by_user {
    die
      "Non-subclassed restrict_by_user method called - this shouldn't have happened";
}

1;
