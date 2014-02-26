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
package Opsview::Utils::NagiosSyncStatus;

use strict;
use warnings;

use Template;
use Nagios::StatusLog;
use base 'Class::Accessor::Fast';

# This points to the sync.tt file - is used by this library for slave_node_resync, cluster_node_takeover_hosts and sync_cluster_node_status
my $sync_tt_dir = "/usr/local/nagios/bin";

sub generate {
    my ( $self, $attrs ) = @_;
    my $status_dat    = $attrs->{status_file};
    my $targetdir     = $attrs->{targetdir};
    my $host_to_slave = $attrs->{slave_lookup};
    my $suffix        = "";
    if ( $attrs->{suffix} ) {
        $suffix = "." . $attrs->{suffix};
    }

    my $slave_objects;
    my %slavenames = reverse %$host_to_slave;
    foreach my $slavename ( keys %slavenames ) {
        $slave_objects->{$slavename} = { original => [] };
    }

    my $log = Nagios::StatusLog->new(
        Filename => $status_dat,
        Version  => 3.0,
    );

    my $common_id_attrs = sub {
        my ( $hostname, $service_description ) = @_;
        my $a = { host_name => $hostname };
        if ($service_description) {
            $a->{service_description} = $service_description;
        }
        return $a;
    };
    my $common_object_attributes = sub {
        my $object = shift;
        my $h      = {
            current_state => $object->current_state,
            plugin_output => $object->plugin_output,
            last_check    => $object->last_check,
            problem_has_been_acknowledged =>
              $object->problem_has_been_acknowledged,
            has_been_checked => $object->has_been_checked,
            last_hard_state  => $object->last_hard_state,
        };
        return $h;
    };
    my $common_comment_attributes = sub {
        my $c = shift;
        return {
            entry_type   => $c->entry_type,
            source       => $c->source,
            persistent   => $c->persistent,
            entry_time   => $c->entry_time,
            expires      => $c->expires,
            expire_time  => $c->expire_time,
            author       => $c->author,
            comment_data => $c->comment_data
        };
    };
    my $common_downtime_attributes = sub {
        my $d = shift;
        return {
            entry_time => $d->entry_time,
            start_time => $d->start_time,
            end_time   => $d->end_time,
            author     => $d->author,
            comment    => $d->comment,
            duration   => $d->duration,
            fixed      => $d->fixed,
        };
    };

    # Hosts
    foreach my $hostname ( $log->list_hosts ) {
        my $host      = $log->host($hostname);
        my $slavename = "";
        next unless defined( $slavename = $host_to_slave->{$hostname} );
        my $attrs = {
            type => "host",
            %{ $common_id_attrs->($hostname) },
            %{ $common_object_attributes->($host) }
        };

        push @{ $slave_objects->{$slavename}->{original} }, $attrs;

        # Host Comments
        my $commentids = $log->hostcomment($hostname);
        foreach my $commentid ( keys %$commentids ) {
            my $comment = $commentids->{$commentid};

            # Ignore downtime comments because these are deleted and recreated internally
            next if $comment->entry_type == 2;

            push @{ $slave_objects->{$slavename}->{original} },
              {
                type => "hostcomment",
                %{ $common_id_attrs->($hostname) },
                %{ $common_comment_attributes->($comment) }
              };
        }

        # Host Downtimes
        my $downtimeids = $log->hostdowntime($hostname);
        foreach my $did ( keys %$downtimeids ) {
            my $downtime = $downtimeids->{$did};

            push @{ $slave_objects->{$slavename}->{original} },
              {
                type => "hostdowntime",
                %{ $common_id_attrs->($hostname) },
                %{ $common_downtime_attributes->($downtime) }
              };
        }

        # Services
        foreach my $servicename ( $log->list_services_on_host($hostname) ) {
            my $service = $log->service( $hostname, $servicename );
            my $attrs = {
                type => "service",
                %{ $common_id_attrs->( $hostname, $servicename ) },
                %{ $common_object_attributes->($service) }
            };

            push @{ $slave_objects->{$slavename}->{original} }, $attrs;

            # Comments
            my $commentids = $log->servicecomment( $hostname, $servicename );
            foreach my $commentid ( keys %$commentids ) {
                my $comment = $commentids->{$commentid};

                # Ignore downtime comments because these are deleted and recreated internally
                next if $comment->entry_type == 2;
                my $attrs = {
                    type => "servicecomment",
                    %{ $common_id_attrs->( $hostname, $servicename ) },
                    %{ $common_comment_attributes->($comment) }
                };

                push @{ $slave_objects->{$slavename}->{original} }, $attrs;
            }

            # Downtimes
            my $downtimeids = $log->servicedowntime( $hostname, $servicename );
            foreach my $did ( keys %$downtimeids ) {
                my $downtime = $downtimeids->{$did};

                push @{ $slave_objects->{$slavename}->{original} },
                  {
                    type => "servicedowntime",
                    %{ $common_id_attrs->( $hostname, $servicename ) },
                    %{ $common_downtime_attributes->($downtime) }
                  };
            }
        }

    }

    # Print sync.dat per slave
    foreach my $slavename ( keys %$slave_objects ) {
        my $types = $slave_objects->{$slavename};

        my @objects = ( @{ $types->{original} } );

        my $template = Template->new( INCLUDE_PATH => "$sync_tt_dir" );
        $template->process(
            "sync.tt",
            { objects => \@objects },
            "$targetdir/$slavename/sync.dat$suffix"
        ) or print $template->error;
    }
}

1;
