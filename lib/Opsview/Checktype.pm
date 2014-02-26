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

package Opsview::Checktype;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 1555 $';

__PACKAGE__->table( "checktypes" );

__PACKAGE__->columns( Essential => qw/id name priority/, );

__PACKAGE__->columns( Stringify => qw/name/ );

__PACKAGE__->has_many(
    servicechecks => [ "Opsview::Servicecheck" => "checktype" ],
    { cascade => "Fail" }
);

__PACKAGE__->default_search_attributes( { order_by => "priority" } );

# Override retrieve_all to remove priority == 0 checktypes (these are deprecated checktypes)
sub retrieve_all {
    shift->search( { priority => { ">" => 0 } }, { order_by => "priority" } );
}

=head1 NAME

Opsview::Checktype - Accessing checktypes table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview checktype information

=head1 METHODS

=over 4

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
