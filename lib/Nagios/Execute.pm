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
package Nagios::Execute;

use strict;
use warnings;

sub new {
    my ( $class, $util, %args ) = @_;
    my $self = {
        'util' => $util,
        'args' => \%args
    };
    bless $self, $class;
}

sub util {
    my ( $self, $util ) = @_;
    if ( defined $util ) {
        $self->{'util'} = $util;
    }
    return $self->{'util'};
}

sub run {
    my ( $self, %extra ) = @_;

    my $sleep_count = 0;
    my ( $pid, $output );

    do {
        $pid = open( KID_TO_READ, "-|" );
        unless ( defined $pid ) {
            warn "cannot fork: $!";
            die "cannot fork: bailing out after $sleep_count attempts"
              if $sleep_count++ > 6;
            sleep 10;
        }
    } until defined $pid;

    if ($pid) { # parent
        while (<KID_TO_READ>) {
            $output .= $_;
        }
        close(KID_TO_READ);
        return ( ( $? >> 8 ), $output );

    }
    else {      # child
        my %wantedenv = ( %{ $self->{'args'} }, %extra );
        %ENV = ();
        map { $ENV{$_} = $wantedenv{$_} } keys %wantedenv;
        exec( $self->{'util'} ) || exit 255;
    }

}

1;
