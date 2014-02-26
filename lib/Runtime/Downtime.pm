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

package Runtime::Downtime;
use base 'Runtime';
use base ( qw(Runtime::Action) );

use strict;

__PACKAGE__->table( "nagios_scheduleddowntime" );
__PACKAGE__->utf8_columns(qw/comment_data/);
__PACKAGE__->columns( Primary => qw/scheduleddowntime_id/ );
__PACKAGE__->columns(
    Essential => qw/
      downtime_type author_name comment_data entry_time scheduled_start_time
      scheduled_end_time actual_start_time was_started
      /
);

__PACKAGE__->has_datetime( "scheduled_start_time" );
__PACKAGE__->has_datetime( "scheduled_end_time" );
__PACKAGE__->has_datetime( "entry_time" );
__PACKAGE__->has_datetime( "actual_start_time" );

# Cannot tell at this point how to relate back to host or service, so do not
# set link up - need more intelligence in caller to use downtime_type where
# 1 = service and 2 = host
#__PACKAGE__->has_a( object_id => "Runtime::blahblahbah" );

=head1 NAME

Runtime::Downtime - Generic access to nagios_scheduleddowntime table

=head1 DESCRIPTION

Handles interaction with database for Runtime's nagios_scheduleddowntime 
information

=head1 METHODS

=item list_all_downtime_with_same_entrytime

Returns a list of all downtime objects with the same entrytime as the
given id

=cut

sub list_all_downtime_with_same_entrytime {
    my ($self) = @_;

    my $sql = "
SELECT scheduleddowntime_id,downtime_type
FROM nagios_scheduleddowntime
WHERE entry_time = ?
";

    my $sth = $self->db_Main->prepare_cached($sql);
    $sth->execute( $self->entry_time );

    my @list;
    while ( my $hash = $sth->fetchrow_hashref ) {
        if ( $hash->{downtime_type} == 1 ) {
            push(
                @list,
                Runtime::Servicedowntime->retrieve(
                    $hash->{scheduleddowntime_id}
                )
            );
        }
        else {
            push(
                @list,
                Runtime::Hostdowntime->retrieve(
                    $hash->{scheduleddowntime_id}
                )
            );
        }
    }

    return @list;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
