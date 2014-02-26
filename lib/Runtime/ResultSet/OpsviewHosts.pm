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

package Runtime::ResultSet::OpsviewHosts;

use strict;
use warnings;

use Opsview::Utils
  qw(convert_to_arrayref convert_state_to_text convert_host_state_to_text convert_state_type_to_text);
use List::MoreUtils qw( uniq );

use base qw/Runtime::ResultSet/;

sub list_summary {
    my ( $self, $filters, $args ) = @_;
    $args ||= {};

    # Object specific filtering
    $self =
      $self->search( { "hostgroups.hostgroup_id" => $filters->{hostgroupid} },
        { join => "hostgroups" } )
      if ( exists $filters->{hostgroupid} );

    $self = $self->search( { "me.name" => $filters->{host} } )
      if ( exists $filters->{host} );
    $args->{comments_hash} = $self->_comments_hash( "me.id" );

    $self = $self->search( {}, { join => "host_objects" } );
    $self =
      $self->search( { "host_objects.name2" => $filters->{servicecheck} } )
      if ( exists $filters->{servicecheck} );

    if ( $filters->{only_with_children} ) {
        $self = $self->search( { 'me.num_children' => { '!=' => 0 }, } );
    }

    if ( $filters->{monitoredby} ) {
        $self =
          $self->search( { 'me.monitored_by' => $filters->{monitoredby}, } );
    }

    # Root host
    if ( exists $filters->{fromhostname} ) {
        my $hostnames = convert_to_arrayref( $filters->{fromhostname} );
        my @matpaths = map { $_->{matpath} . "%" } $self->search(
            { "me.name" => $hostnames },
            {
                result_class => "DBIx::Class::ResultClass::HashRefInflator",
                join         => 'matpaths',
                select       => 'matpaths.matpath',
                as           => 'matpath',
            }
        )->all;
        $self = $self->search(
            { 'matpaths.matpath' => { '-like' => [ uniq(@matpaths) ] } },
            {
                join     => 'matpaths',
                group_by => "me.id",
            }
        );
    }

    $self->next::method( $filters, $args );
}

sub _downtimes_hash {
    my ( $self, $key ) = @_;
    $self = $self->search( {}, { join => { "host_objects" => "downtimes" } } );
    $self->next::method( "me.id" );
}

sub _comments_hash {
    my ( $self, $key ) = @_;
    $self = $self->search( {}, { join => "comments" } );
    $self->next::method($key);
}

sub create_summarized_resultset {
    my ( $self, $downtimes, $filters, $args ) = @_;

    my $comments = $args->{comments_hash};

    $self =
      $self->search( {},
        { join => [ "hoststatus", { "host_objects" => "servicestatus" } ] }
      );

    $self = $self->search(
        {},
        {
            '+select' => [ 'hostgroup.matpath', 'hostgroup.matpathid', ],
            '+as'     => [ 'matpath',           'matpathid', ],
            join      => 'hostgroup'
        }
    ) if $filters->{includeextradetails};

    #<<<
    $self = $self->search( {},
        {
            "+select" => [
                "me.id",
                "me.name",
                "me.ip",
                "me.alias",
                "me.icon_filename",
                "hoststatus.is_flapping",
                "hoststatus.problem_has_been_acknowledged",
                "me.num_interfaces",
                "me.num_services",
                "hoststatus.output",
                "hoststatus.current_check_attempt",
                "hoststatus.max_check_attempts",
                "hoststatus.state_type",
                \"UNIX_TIMESTAMP(hoststatus.last_check)",
                \"UNIX_TIMESTAMP(hoststatus.last_state_change)",
                \"count(*)",
            ],
            "+as" => [
                "id",
                "hostname",
                "ip",
                "alias",
                "icon",
                "flapping",
                "acknowledged",
                "num_interfaces",
                "num_services",
                "output",
                "current_check_attempt",
                "max_check_attempts",
                "host_state_type",
                "host_last_check_timev",
                "host_last_state_change_timev",
                "total",
            ],
            "group_by" => [ "me.id", "servicestatus.current_state", "service_unhandled" ],
            "order_by" => [ "me.name" ],
        }
    );
    #>>>
    # SQL returns back something like:
    # hostgroup_name, hostgroupid,  host_object_id, host_state, host_unhandled, service_state, service_unhandled, total
    # hostgroup133,   133,          7004,           0,          0,              3,             1,                 2
    # hostgroup19,    19,           6428,           1,          1,              2,             0,                 3
    # hostgroup19,    19,           6428,           1,          1,              3,             0,                 17
    # hostgroup19,    19,           6609,           2,          1,              2,             0,                 2
    # Use this to convert to our webservice response
    my @list;
    my $group_key;
    my $group_label;
    my @extra_group_fields;

    $group_key = $group_label = "hostname";
    @extra_group_fields =
      qw(icon alias num_interfaces num_services output current_check_attempt max_check_attempts);

    my $now              = time();
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
        $status->{state} =
          convert_host_state_to_text( $last_hash->{host_state} );
        $status->{state_duration} =
          $now - $last_hash->{host_last_state_change_timev};
        $status->{state_type} =
          convert_state_type_to_text( $last_hash->{host_state_type} );
        $status->{last_check} =
          DateTime->from_epoch( epoch => $last_hash->{host_last_check_timev} );

        $status->{flapping} = $last_hash->{flapping}
          if $last_hash->{flapping}
          or $filters->{includeextradetails};

        $status->{acknowledged} = 1 if $last_hash->{acknowledged};
        $status->{comments} = $comments->{ $last_hash->{id} }
          if exists $comments->{ $last_hash->{id} };
        $status->{unhandled} = $last_hash->{host_unhandled};

        $status->{summary}->{total} =
          $status->{summary}->{unhandled} + $status->{summary}->{handled};

        $status->{last_state_change} = $last_hash->{last_state_change}
          if exists $last_hash->{last_state_change};
        $status->{last_notification} = $last_hash->{last_notification}
          if exists $last_hash->{last_notification};
        $status->{notification_number} =
          $last_hash->{current_notification_number}
          if exists $last_hash->{current_notification_number};
        $status->{flap_detection_enabled} = $last_hash->{flap_detection_enabled}
          if exists $last_hash->{flap_detection_enabled};

        if ( $filters->{includeextradetails} ) {
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
            $status->{hostgroup} = \@matpath;
        }

        $summary->{service}->{unhandled} += $status->{summary}->{unhandled};
        $summary->{service}->{total}     += $status->{summary}->{total};

        $summary->{host}
          ->{ convert_host_state_to_text( $last_hash->{host_state} ) }++;
        $summary->{host}->{unhandled}++ if $last_hash->{host_unhandled};
        $summary->{host}->{total}++;

        push @list, $status;
    };
    while ( my $hash = $self->next ) {

        # Save host information on changes
        if ( $last_group_key ne $hash->{$group_key} ) {
            if ( $last_group_label ne "" ) {
                &$inner_sub;
            }
            $status = {
                summary => {
                    handled   => 0,
                    unhandled => 0
                },
                downtime => $downtimes->{ $hash->{id} }->{state} || 0,
            };
            $last_group_label = $hash->{$group_label};
            $last_group_key   = $hash->{$group_key};
            $last_hash        = $hash;
        }

        my $key;
        if ( $hash->{service_unhandled} ) {
            $key = "unhandled";
        }
        else {
            $key = "handled";
        }
        $status->{summary}->{$key} += $hash->{total};

        $_ = convert_state_to_text( $hash->{service_state} );
        $status->{summary}->{$_}->{$key} = $hash->{total};
        $summary->{service}->{$_} += $hash->{total};
    }

    # Set the grouped information, needed if only one group retrieved
    if ($last_group_key) {
        &$inner_sub;
    }

    if ( $filters->{include_reload_time} ) {
        my $web_status = Opsview::Nagios->web_status( { returns => "hash" } );
        $summary->{last_reload_time} = $web_status->{lastupdated};
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

    # Don't call next
    #$self->next::method( $downtimes, $args );
}

# Compatibility layer for object_info_base, which expects Class::DBI-isms
sub retrieve {
    shift->find(@_);
}

sub restrict_by_user {
    my ( $rs, $user ) = @_;
    $rs = $rs->search(
        { "contacts.contactid" => $user->id },
        { join                 => { "host_objects" => "contacts" } },
    );
    return $rs;
}

1;
