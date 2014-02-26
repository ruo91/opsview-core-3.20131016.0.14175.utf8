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

package Opsview::Reloadmessage;
use base 'Opsview';

use strict;
use DateTime;

our $VERSION = '$Revision: 1674 $';

__PACKAGE__->table( "reloadmessages" );

__PACKAGE__->columns( Primary   => qw/id/, );
__PACKAGE__->columns( Essential => qw/utime severity monitoringcluster/, );
__PACKAGE__->columns( Others    => qw/message/, );

__PACKAGE__->has_a( monitoringcluster => "Opsview::Monitoringserver" );

__PACKAGE__->has_a(
    utime => 'DateTime',
    inflate =>
      sub { DateTime->from_epoch( epoch => shift, time_zone => "local" ) },
    deflate => sub { shift->epoch }
);

__PACKAGE__->default_search_attributes( { order_by => "monitoringcluster" } );

# Remove \r from message fields
sub normalize_column_values {
    my ( $self, $h ) = @_;
    if ( exists $h->{message} && $h->{message} ) {
        $h->{message} =~ s/\r//g;
    }
}

=head1 NAME

Opsview::Reloadmessage - Messages during an Opsview reload

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview reload messages information

=head1 METHODS

=over 4

=item $class->count_messages_by_severity

Returns a hash with key of severity and value of count. For example: { critical => 1, warning => 4 }

=cut

sub count_messages_by_severity {
    my ($self) = @_;
    my $sth = $self->db_Main->prepare_cached(
        qq{
  SELECT severity, count(*) as count
  FROM reloadmessages
  GROUP BY severity
}
    );
    my $results = {};
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref ) {
        $results->{ $row->{severity} } = $row->{count};
    }
    return $results;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
