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

package Opsview::Monitoringclusternode;
use Opsview;
use Opsview::Sshcommands;
use base qw(Opsview Opsview::Sshcommands);

use strict;
our $VERSION = '$Revision: 2548 $';

__PACKAGE__->table( "monitoringclusternodes" );

__PACKAGE__->columns( Primary => qw/id/, );
__PACKAGE__->columns(
    Essential => qw/monitoringcluster host activated passive uncommitted/, );

__PACKAGE__->has_a( host              => "Opsview::Host" );
__PACKAGE__->has_a( monitoringcluster => "Opsview::Monitoringserver" );
__PACKAGE__->initial_columns( "host", "monitoringcluster" );

# Return name as the host's name and alias
sub name { shift->host->name }
sub ip   { shift->host->ip }

# This sets the specified host to have a monitored_by of this cluster
__PACKAGE__->add_trigger( after_update => \&set_host_monitored_by_update );
__PACKAGE__->add_trigger( after_create => \&set_host_monitored_by_create );

sub set_host_monitored_by_update {
    my $self = shift;
    my $id   = $self->_attrs( "host" );
    return if ( !$id || ref( \$id ) ne "SCALAR" );
    my $host = Opsview::Host->retrieve($id);
    $host->monitored_by( $self->monitoringcluster );
    $host->update;
}

sub set_host_monitored_by_create {
    my $self = shift;
    my $host = $self->host;
    $host->monitored_by( $self->monitoringcluster );
    $host->update;
}

# Need to delete the cache mapping hosts to monitoring servers
sub update {
    my $self = shift;
    $self->SUPER::update(@_);
    delete Opsview::Host->my_cache->{host_ms};
}

=head1 NAME

Opsview::Monitoringclusternode - Nodes used in a monitoring cluster

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for servers in a monitoring cluster

=head1 METHODS

=over 4

=item $class->retrieve_all_activated

Returns a list of Opsview::Monitoringclusternodes which are activated

=cut

# TODO: might be quicker to join
sub retrieve_all_activated {
    my $class = shift;
    map { $_->nodes } (
        Opsview::Monitoringserver->search(
            {
                role      => "Slave",
                activated => 1
            }
        )
    );
}

=item is_activated

Shortcut for $self->monitoringcluster->is_activated

=cut

sub is_activated { shift->monitoringcluster->is_activated }

=item is_passive

Shortcut for $self->monitoringcluster->is_passive

=cut

sub is_passive { shift->monitoringcluster->is_passive }

sub short_name {
    my $self = shift;
    return "node" . $self->id;
}

sub slave_port {
    my $self = shift;
    if ( Opsview::Config->slave_initiated ) {
        return ( Opsview::Config->slave_base_port + $self->id );
    }
    else {
        return 22;
    }
}

=item search_nodes_order_by_host_name($monitoringclusterid)

Returns the list of hosts, ordered by name of host, which is used in the specified monitoring cluster

=cut

__PACKAGE__->set_sql(
    nodes_order_by_host_name => qq{
SELECT monitoringclusternodes.id
FROM hosts, monitoringclusternodes
WHERE monitoringclusternodes.monitoringcluster = ?
AND monitoringclusternodes.host = hosts.id
ORDER BY hosts.name
}
);

=item $class->search_by_node_name( "string" )

Returns an array of Opsview::Host which match string name. If none, will search as substring

=cut

sub search_by_node_name {
    my ( $class, $name ) = @_;
    @_ = __PACKAGE__->search_node_by_name($name);
    unless (@_) {
        @_ = __PACKAGE__->search_node_like_name( "%" . $name . "%" );
    }
    return @_;
}

__PACKAGE__->set_sql(
    node_by_name => qq{
SELECT __ESSENTIAL(me)__
FROM __TABLE__ me, hosts h
WHERE h.name = ?
AND me.host = h.id
}
);

__PACKAGE__->set_sql(
    node_like_name => qq{
SELECT __ESSENTIAL(me)__
FROM __TABLE__ me, hosts h
WHERE h.name LIKE ?
AND me.host = h.id
}
);

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
