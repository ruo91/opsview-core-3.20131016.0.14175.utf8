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

package Opsview::Role;
use base 'Opsview';
use base 'Opsview::Role::Constants';

use constant ADMIN    => Opsview::Role::Constants::ADMIN;
use constant CURIOUS  => Opsview::Role::Constants::CURIOUS;
use constant FOCUSED  => Opsview::Role::Constants::FOCUSED;
use constant READONLY => Opsview::Role::Constants::READONLY;

use strict;
our $VERSION = '$Revision: 1793 $';

__PACKAGE__->table( "roles" );

__PACKAGE__->columns( Primary   => qw/id/ );
__PACKAGE__->columns( Essential => qw/name/ );

#__PACKAGE__->columns( Other     => qw/fixedname/ );

__PACKAGE__->has_many(
    contacts => "Opsview::Contact",
    { cascade => "Fail" }
);

=head1 NAME

Opsview::Role - Accessing roles table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview roles information

=head1 METHODS

=over 4

=item $self->is_readonly

Returns 1 if the role is read only, 0 otherwise

=cut

sub is_readonly {
    my $self = shift;

    return $self->id == READONLY ? 1 : 0;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
