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

package Opsview::Nagios;
use strict;
use Opsview::Config;

# Make these global so that the testing program can see
my $root_dir = Opsview::Config->root_dir;
our $reload_flag   = "$root_dir/var/rw/reload_flag";
our $config_output = "$root_dir/var/rw/config_output";
our $mrtg_output   = "$root_dir/var/log/mrtgconfgen.log";
our $pid_file      = "$root_dir/var/nagios.lock";
our $nagios_cfg    = "$root_dir/etc/nagios.cfg";
our $nagios_pid; # Save the nagios pid over sessions, to save reading

=item Opsview::Nagios->web_status( { returns => "xml" } )

Will return an xml string with status information. Can return hash if requested

=cut

use XML::Simple;
my $xs = XML::Simple->new(
    NoAttr   => 1,
    RootName => "opsview"
);

sub web_status {
    my ( $class, $opts ) = @_;
    my $hash = {};

    my $running = 0;
    if ($nagios_pid) {
        $running = kill 0, $nagios_pid;
    }

    # If not running, reread the pid file in case has changed
    unless ($running) {

        # If no file, is left as dead
        if ( -f $pid_file ) {
            open F, $pid_file;
            chomp( $nagios_pid = <F> );
            close F;
            $running = kill 0, $nagios_pid;
        }
    }

    if ($running) {
        if ( -f $reload_flag ) {
            $hash->{status} = 1;
        }
        else {
            require Opsview::Reloadmessage;
            my $messages = Opsview::Reloadmessage->count_messages_by_severity;
            if ( -e $config_output ) {
                $hash->{status} = 3;
            }
            elsif ( $messages->{critical} ) {
                $hash->{status} = 3;
            }
            elsif ( $messages->{warning} ) {
                $hash->{status} = 4;
            }
            else {
                $hash->{status} = 0;
            }
        }
    }
    else {
        $hash->{status} = 2;
    }
    $hash->{lastupdated} = ( stat($nagios_cfg) )[9];

    if ( exists $opts->{returns} && $opts->{returns} eq "hash" ) {
        return $hash;
    }
    else {
        $hash->{lastupdated} = scalar localtime( $hash->{lastupdated} );
        return $xs->XMLout($hash);
    }
}

1;
