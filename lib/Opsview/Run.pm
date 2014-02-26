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

package Opsview::Run;
require Exporter;

use strict;
use warnings;

our @ISA       = qw(Exporter);
our @EXPORT    = qw( run_command_subcap );
our @EXPORT_OK = qw ( );
our $VERSION   = '0.01';

use IPC::Run;
use IPC::Run::SafeHandles;

=item ($rc, $stdout, $stdout) = Opsview::Run->run_command(@cmd)

Runs the command in $cmd[0] with args @cmd[1 .. -1].  Any errors from running
the commands will be put into $@.  

The first element of the returned array is the exit code.  The second element
is an arrayref of the STDOUT output from the command, the third is an arrayref
of the STDERR output.

The stdout and stderr arrays are split based on linefeeds.

Note: The values in the stdout and stderr arrays will always end in a linefeed

=cut

sub run_command(@) {
    my ( $class, @command ) = @_;

    my ( $stdout_string, $stderr_string );
    my $harness;

    # this is required to IPC::Run can reap children properly
    local $SIG{CHLD} = 'DEFAULT';

    eval {
        $harness = IPC::Run::start(
            \@command,
            ">",
            sub {
                $stdout_string .= $_[0];
            },

            "2>",
            sub {
                $stderr_string .= $_[0];
            },
        );
        $harness->finish;
    };

    if ($@) {
        $@ =~ s/ at .*//s;
        chomp($@);
        return ( undef, undef, undef );
    }

    my ( $stdout_return, $stderr_return );
    if ($stdout_string) {
        my @stdout = map { $_ .= "\n" } split( "\n", $stdout_string );
        $stdout_return = \@stdout;
    }
    if ($stderr_string) {
        my @stderr = map { $_ .= "\n" } split( "\n", $stderr_string );
        $stderr_return = \@stderr;
    }
    return ( $harness->full_result(0), $stdout_return, $stderr_return );
}

=item $rc = run_command_subcap(\@cmd, \&capture_out_func, \&capture_err_func);

Runs command and its arguments, calling the sub references (if defined) 
with output from the command as arguments. The 1st and only argument to &capture_out_func and &capture_err_func is
a string containing the output since until a timeout or 10000 bytes. You should take this input and append to previous
data

=cut

sub run_command_subcap($&&) {
    my ( $command, $out_sub, $err_sub ) = @_;

    my $harness;

    # this is required to IPC::Run can reap children properly
    local $SIG{CHLD} = 'DEFAULT';

    eval {
        $harness = IPC::Run::start(
            \@$command,
            ">",
            sub {
                if ( defined($out_sub) ) {
                    &$out_sub( $_[0] );
                }
            },

            "2>",
            sub {
                if ( defined($err_sub) ) {
                    &$err_sub( $_[0] );
                }
            },
        );
        $harness->finish;
    };

    if ($@) {
        $@ =~ s/ at .*//s;
        chomp($@);
        return ( undef, undef, undef );
    }

    return $harness->full_result(0);
}

1;
