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

# This will be renamed to be Monitoringcluster
package Opsview::__::Monitoringserver;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 2628 $';

__PACKAGE__->table( "monitoringservers" );

__PACKAGE__->columns( Primary => qw/id/, );
__PACKAGE__->columns(
    Essential => qw/name role host activated passive uncommitted/, );

__PACKAGE__->has_a( host => "Opsview::Host", )
  ; # this only makes sense for a master

package Opsview::Monitoringserver;
use base 'Opsview::__::Monitoringserver';
use strict;
use Carp;
use Opsview::Connections;

# This must come before any cascade fails so this trigger gets called first
__PACKAGE__->add_trigger( before_delete => \&before_deleting_ms );
__PACKAGE__->add_constraint( 'one_master', role => \&check_one_master );

__PACKAGE__->constrain_column_regexp( name => q{/^[\w\. \+_-]+$/} =>
      "invalidCharactersOnlyAlphanumericsOrPeriodPlusUnderscoreDash" );

__PACKAGE__->has_many(
    monitors => "Opsview::Host",
    {
        order_by => "name",
        cascade  => "Fail"
    }
);
__PACKAGE__->initial_columns( "role", "name" );
__PACKAGE__->has_many(
    nodes => ["Opsview::Monitoringclusternode"],
    "monitoringcluster"
); # this only makes sense for a slave cluster
__PACKAGE__->has_many( reloadmessages => "Opsview::Reloadmessage" );

# Return master first
__PACKAGE__->default_search_attributes( { order_by => "role" } );

__PACKAGE__->set_sql( join_monitors => <<"" );
SELECT __ESSENTIAL(me)__
FROM %s
WHERE %s
GROUP BY __ESSENTIAL(me)__
%s %s

__PACKAGE__->add_trigger( before_create => \&check_name_set );

sub check_name_set {
    my $self = shift;
    unless ( $self->{name} ) {
        $self->_croak( "Must specify a name to create a new monitoringserver"
        );
    }
}

# This sets the monitoringserver's host to have a monitored_by of this server
__PACKAGE__->add_trigger( after_update => \&set_host_monitored_by_update );
__PACKAGE__->add_trigger( after_create => \&set_host_monitored_by_create );

sub set_host_monitored_by_update {
    my $self = shift;
    my $id   = $self->_attrs( "host" );
    return if ( !$id || ref( \$id ) ne "SCALAR" );
    my $host = Opsview::Host->retrieve($id);
    $host->monitored_by($self);
    $host->update;
}

sub set_host_monitored_by_create {
    my $self = shift;
    if ( $self->is_master ) {
        my $it = Opsview::Host->search( monitored_by => undef );
        while ( my $h = $it->next ) {
            $h->monitored_by($self);
            $h->update;
        }
    }
}
__PACKAGE__->add_trigger( after_update => \&write_connections_file );
__PACKAGE__->add_trigger( after_delete => \&write_connections_file );

# Maybe this should belong in Opsview::Connections?
# connections.dat gets written after every change to the monitoringservers page
# and at nagconfgen time
# Make sure this is in sync with Opsview::Connections' read routine
sub write_connections_file {
    my $self = shift;
    my $file = Opsview::Connections->connections_file;
    open F, "> $file" or $self->_croak( "Cannot write to $file" );
    my $it = Opsview::Monitoringclusternode->retrieve_all;
    if ( Opsview::Config->slave_initiated ) {
        while ( my $node = $it->next ) {
            print F join( ":",
                $node->name, $node->is_activated,
                "127.0.0.1", $node->slave_port ),
              $/;
        }
    }
    else {
        while ( my $node = $it->next ) {
            print F
              join( ":", $node->name, $node->is_activated, $node->ip, 22 ), $/;
        }
    }
    close F;
}

sub short_name {
    my $self = shift;
    if ( $self->is_master ) {
        return "master";
    }
    else {
        return "slave" . $self->id;
    }
}

# Overridden methods
sub activated {
    my $self = shift;
    if (@_) {
        if ( $_[0] == 0 && $self->is_master ) {

            # Ignore attempts to deactivate master
            return $self->SUPER::activated;
        }
        else {
            return $self->SUPER::activated(@_);
        }
    }
    else {
        return $self->SUPER::activated;
    }
}

sub passive {
    my $self = shift;
    if (@_) {
        if ( $_[0] == 1 && $self->is_master ) {

            # Ignore attempts to set master as passive
            return $self->SUPER::passive;
        }
        else {
            return $self->SUPER::passive(@_);
        }
    }
    else {
        return $self->SUPER::passive;
    }
}

# Need to delete the cache mapping hosts to monitoring servers
sub update {
    my $self = shift;
    $self->SUPER::update(@_);
    delete Opsview::Host->my_cache->{host_ms};
}

sub host {
    my $self = shift;
    if ( $self->is_slave ) {
        @_ = $self->nodes;
        return $_[0]->host;
    }
    else {
        return $self->SUPER::host(@_);
    }
}

# End overridden methods

# Stop deletion of Master server
sub before_deleting_ms {
    my $self = shift;
    if ( $self->role eq "Master" ) {
        $self->_croak( "Cannot delete Master monitoringserver" );
    }
    else {

        # Move all hosts monitored by this cluster
        # to master
        my $master = $self->get_master;
        foreach my $h ( $self->monitors ) {
            $h->monitored_by($master);
            $h->update;
        }
    }
}

sub check_one_master {
    my ( $value, $self ) = @_;
    if ( $value eq "Master" && $self->get_master ) {

        #$self->_croak("Can only have one master monitoringserver");
        return 0;
    }
    return 1;
}

=head1 NAME

Opsview::Monitoringservers - List of all Opsview servers

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for list of Opsview servers

=head1 METHODS

=over 4

=item Opsview::Monitoringserver->get_master

Returns the object to the Master server. Returns undef if not defined

=cut

sub get_master {
    my $class = shift;
    my ($master) = $class->search( role => "Master" );
    return $master;
}

=item is_master

Convenience function to return true if this is a master

=cut

sub is_master {
    my $self = shift;
    ( $self->role eq "Master" ) ? 1 : 0;
}

=item is_slave

Ditto

=cut

sub is_slave {
    my $self = shift;
    ( $self->role eq "Slave" ) ? 1 : 0;
}

=item is_active

Returns true if this monitoring server is a master OR it is a slave with the 
activated field set AND has at least 1 monitored host

=cut

sub is_active {
    my $self = shift;
    ( $self->is_master || ( $self->monitors && $self->activated ) ) ? 1 : 0;
}

=item is_activated {

Returns true if this monitoring server is a master OR is a slave with
activated field set. Different from is_active because doesn't care if has any monitored hosts

=cut

sub is_activated {
    my $self = shift;
    ( $self->is_master || $self->activated ) ? 1 : 0;
}

=item is_passive

Returns false if this monitoring server is a master OR it is a slave with the 
passive field unset

=cut

sub is_passive {
    my $self = shift;
    ( $self->is_master || !$self->passive ) ? 0 : 1;
}

=item hosts

Returns a list of Opsview::Host objects which this monitoring cluster uses

=cut

sub hosts {
    my $self = shift;
    if ( $self->is_master ) {
        return ( $self->host );
    }
    else {
        return map { $_->host } $self->nodes;
    }
}

=item $class->retrieve_slaves

Returns a list of Opsview slaves as objects

=cut

sub retrieve_slaves {
    my $class  = shift;
    my @slaves = $class->retrieve_from_sql(
        qq{
		role = "Slave"
		ORDER BY name
	}
    );
    return @slaves;
}

=item $self->retrieve_free_hosts

Returns a list of Opsview::Host objects which are not currently used. Returns self in list

=cut

sub retrieve_free_hosts {
    return Opsview::Host->retrieve_non_monitoringserver_hosts(shift);
}

=item $class->search_for_host( $Opsview::Host )

Returns an Opsview::Monitoringserver object if host is used. Otherwise null

=cut

__PACKAGE__->set_sql( for_host_in_ms_mcn => <<"" );
SELECT __ESSENTIAL(me)__
FROM __TABLE__ me
LEFT JOIN monitoringclusternodes mcn
ON me.id = mcn.monitoringcluster
WHERE me.host = ?
OR mcn.host = ?


sub search_for_host {
    my ( $class, $host ) = @_;
    return $class->search_for_host_in_ms_mcn( $host->id, $host->id )->first;
}

=item $class->retrieve_all_nodes_hash

Returns a hash of node ip and the Opsview::Monitoringserver or Opsview::Monitoringclusternode object. For master and
all slaves

=cut

sub retrieve_all_nodes_hash {
    my $class = shift;
    my $hash  = {};
    my $m     = $class->get_master;
    $hash->{ $m->host->ip } = $m;
    foreach my $node ( Opsview::Monitoringclusternode->retrieve_all ) {
        $hash->{ $node->host->ip } = $node->monitoringcluster;
    }
    return $hash;
}

=item $self->monitors_perfmon($perfmon)

Returns a list of Opsview::Host objects where $perfmon is monitored

=cut

sub monitors_perfmon {
    my ( $self, $perfmon ) = @_;
    my @monitors = $self->monitors;
    my @hosts    = $perfmon->all_hosts;
    my %a;
    map { $a{ $_->id }++ }
      @hosts; # Can't use normal intersection because these are objects
    my @b;
    foreach $_ (@monitors) {
        push @b, $_ if $a{ $_->id };
    }
    return @b;
}

=item set_hosts_to

Sets the foreign key table with only the list of hosts specified. Tries to avoid deleting and
recreating unnecessarily

=cut

sub set_hosts_to {
    my $self = shift;
    my $nodes;
    map { $nodes->{ $_->host } = $_ } (
        Opsview::Monitoringclusternode->search(
            monitoringcluster => $self->id
        )
    );
    foreach $_ (@_) {
        if ( $nodes->{$_} ) {
            delete $nodes->{$_};
        }
        else {
            $self->add_to_nodes(
                {
                    monitoringcluster => $self->id,
                    host              => $_
                }
            );
        }
    }
    foreach $_ ( keys %$nodes ) {
        $nodes->{$_}->delete;
    }
}

sub ordered_nodes {
    my $self = shift;
    if ( $self->is_master ) {
        $self->host;
    }
    else {
        Opsview::Host->search_ordered_nodes( $self->id );
    }
}

sub nodes_order_by_host_name {
    my $self = shift;
    if ( $self->is_master ) {
        $self->host;
    }
    else {
        Opsview::Monitoringclusternode->search_nodes_order_by_host_name(
            $self->id );
    }
}

=item $self->monitors_list

Returns array of hosts monitored by this monitoring server. Removes itself and any cluster nodes

=cut

sub monitors_list {
    my $self = shift;
    my %nodes;
    map { $nodes{$_}++ } $self->ordered_nodes;
    my @list;
    my $it = $self->monitors;
    while ( my $host = $it->next ) {
        next if ( $nodes{$host} );
        push @list, $host;
    }
    return @list;
}

=item my_type_is

Returns "monitoring server"

=cut

sub my_type_is {
    return "monitoring server";
}
sub my_web_type {"monitoringserver"}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
