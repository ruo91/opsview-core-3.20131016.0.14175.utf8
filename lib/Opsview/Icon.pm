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

package Opsview::Icon;
use base qw(Opsview Opsview::Base::Icon);

use strict;
our $VERSION = '$Revision: 2652 $';

__PACKAGE__->table( "icons" );

__PACKAGE__->columns( All => qw/name filename/, );

#__PACKAGE__->columns( Stringify => qw/name/);

__PACKAGE__->has_many(
    hosts => "Opsview::Host" => 'icon',
    { cascade => 'Fail' }
);

=head1 NAME

Opsview::Icon - Accessing icons table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview icon information

=head1 METHODS

=over 4

=item filename_jpg, filename_png, filename_gd2

Returns the jpg filename

=cut

sub filename_png { my $self = shift; return $self->filename . ".png" }

sub filename_small_png {
    my $self = shift;
    return $self->filename . "_small.png";
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
