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

package Opsview::AgentPlugin;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 284 $';

__PACKAGE__->table( "agentplugins" );

__PACKAGE__->columns( Primary => qw/agentid pluginname/, );

__PACKAGE__->has_a( agentid    => 'Opsview::Agent' );
__PACKAGE__->has_a( pluginname => 'Opsview::Plugin' );

sub truncate {
    my $class = shift;
    my $dbh   = $class->db_Main;
    $dbh->do( "TRUNCATE agentplugins" );
}

=head1 NAME

Opsview::AgentPlugin - Accessing agentplugins table

=head1 SYNOPSIS

This table describes which plugins are available for each agent

=head1 DESCRIPTION

Handles interaction with database for Opsview agentplugins information

=head1 METHODS

=over 4

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
