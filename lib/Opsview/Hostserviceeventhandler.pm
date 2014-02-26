#
# ORIGINAL AUTHOR:
#	CAPSiDE SL
#
# COPYRIGHT:
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

package Opsview::Hostserviceeventhandler;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 855 $';

__PACKAGE__->table( "hostserviceeventhandlers" );

__PACKAGE__->columns( Primary => qw/hostid servicecheckid/, );

__PACKAGE__->columns( Essential => qw/event_handler/, );

# Must compose of alphanumerics, $'s and spaces (to cater for MACROS args)
# and not empty
__PACKAGE__->constrain_column_regexp( event_handler => q{/^[\w\.\$ -]+$/} =>
      "invalidCharactersOnlyAlphanumericsOrPeriodDashSpaceDollar" );

__PACKAGE__->has_a( servicecheckid => 'Opsview::Servicecheck' );
__PACKAGE__->has_a( hostid         => 'Opsview::Host' );

sub name { shift->hostid->name }

=head1 NAME

Opsview::Hostserviceeventhandler - setup eventhandlers for a specific service check for a specific host

=head1 AUTHOR

CAPSiDE SL

=head1 LICENSE

GNU General Public License v2

=cut

1;
