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

package Runtime::Hoststatus;
use base 'Runtime';

use strict;

__PACKAGE__->table( "nagios_hoststatus" );

__PACKAGE__->columns( Primary => qw/host_object_id/ );
__PACKAGE__->columns( Essential =>
      qw/current_state output last_check next_check scheduled_downtime_depth problem_has_been_acknowledged/
);

__PACKAGE__->has_datetime( 'last_check' );
__PACKAGE__->has_datetime( 'next_check' );

=head1 NAME

Runtime::Hoststatus - Accessing nagios_hoststatus table

=head1 DESCRIPTION

Handles interaction with database for Runtime's host information

=head1 METHODS

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
