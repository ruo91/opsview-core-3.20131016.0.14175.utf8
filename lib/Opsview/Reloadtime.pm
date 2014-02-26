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

package Opsview::Reloadtime;
use base qw/Opsview/;

use strict;
use DateTime;

__PACKAGE__->table( "reloadtimes" );

__PACKAGE__->columns( All => qw/id start_config end_config duration/ );
__PACKAGE__->add_trigger( before_update => \&calculate_time_taken );

sub calculate_time_taken {
    my $self = shift;
    return if ( defined $self->_attrs("duration") );
    if ( $self->start_config && $self->end_config ) {
        my $config_time;
        $config_time = ( $self->end_config - $self->start_config );
        return unless ( $config_time >= 0 );
        $self->duration($config_time);
        $self->update;
    }
}

# Round up to the highest 10
__PACKAGE__->set_sql(
    average_duration => qq{
SELECT FLOOR(AVG(duration)/10+1)*10
FROM (SELECT duration 
      FROM __TABLE__ 
      ORDER BY id DESC 
      LIMIT 30) AS temp
}
);

sub average_duration {
    my $class = shift;
    my $t     = $class->sql_average_duration->select_val;
    defined $t ? $t : 30;
}

=head1 NAME

Opsview::Reloadtime - Accessing reloadtimes table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview reload times

=head1 METHODS

=over 4

=item Opsview::Reloadtime->last_row

Returns the last row

=cut

__PACKAGE__->set_sql(
    last => qq{
  SELECT __ESSENTIAL__
  FROM __TABLE__
  ORDER BY id DESC
  LIMIT 1
}
);

sub last_row { shift->search_last->first; }

=item Opsview::Reloadtime->in_progress 

Returns a DateTime object for the start time of a running reload, 
else undef if no reload in progress

=cut 

sub in_progress {
    my $class = shift;
    my $row   = $class->last_row;
    if ( $row->end_config ) {
        return undef;
    }
    return DateTime->from_epoch(
        epoch     => $row->start_config,
        time_zone => "local"
    );
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
