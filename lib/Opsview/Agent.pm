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

package Opsview::Agent;
use base qw/Opsview/;

use strict;
our $VERSION = '$Revision: 1588 $';

__PACKAGE__->table( "agents" );

__PACKAGE__->columns( Primary => qw/id/, );

__PACKAGE__->columns( Essential => qw/name/ );
__PACKAGE__->columns( Others    => qw/parent priority command/ );

__PACKAGE__->has_many(
    plugins => [ "Opsview::AgentPlugin" => 'pluginname' ],
    "agentid"
);
__PACKAGE__->has_a( parent => "Opsview::Agent" );

__PACKAGE__->constrain_column( name => qr/^[\w\.-]+$/ )
  ; # Must compose of alphanumerics and not empty

__PACKAGE__->default_search_attributes( { order_by => "priority" } );
__PACKAGE__->initial_columns( "name" );

=head1 NAME

Opsview::Agent - Accessing agents table

=head1 SYNOPSIS

Holds information about Opsview Agents

=head1 DESCRIPTION

Handles interaction with database for Opsview agent information

=head1 METHODS

=over 4

=item set_plugins_to

Deletes the foreign key table and adds only the specified list of plugin names

=cut

sub set_plugins_to {
    my ( $self, $list_ref ) = @_;
    Opsview::AgentPlugin->search( agentid => $self->id )->delete_all;
    foreach my $p (@$list_ref) {
        $self->add_to_plugins(
            {
                agentid    => $self->id,
                pluginname => $p
            }
        );
    }
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
