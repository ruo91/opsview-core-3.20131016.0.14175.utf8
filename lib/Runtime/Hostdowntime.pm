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

package Runtime::Hostdowntime;
use base 'Runtime';
use base ( qw(Runtime::Action) );

use strict;

__PACKAGE__->table( "nagios_scheduleddowntime" );
__PACKAGE__->utf8_columns(qw/comment_data/);
__PACKAGE__->columns( Primary => qw/scheduleddowntime_id/ );
__PACKAGE__->columns(
    Essential => qw/
      object_id author_name comment_data scheduled_start_time scheduled_end_time
      actual_start_time was_started
      /
);

__PACKAGE__->has_a( object_id => "Runtime::Host" );

__PACKAGE__->has_datetime( "scheduled_start_time" );
__PACKAGE__->has_datetime( "scheduled_end_time" );
__PACKAGE__->has_datetime( "actual_start_time" );

=head1 NAME

Runtime::Hostdowntime - Accessing nagios_scheduleddowntime table

=head1 DESCRIPTION

Handles interaction with database for Runtime's nagios_scheduleddowntime 
information

=head1 METHODS

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
