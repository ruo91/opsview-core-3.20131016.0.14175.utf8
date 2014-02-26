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

package Opsview::Sshcommands;
use strict;
use Opsview::Config;
use Opsview::Utils;

my @ssh_options = ( "-o", "ConnectTimeout=10" );

# remove options that dont work on vanilla solaris ssh
if ( $^O =~ /solaris/i ) {
    @ssh_options = ();
}

=head1 NAME

Opsview::Sshcommands - customised ssh/scp commands to talk to slaves

=head1 DESCRIPTION

Common functions to get ssh and scp commands to talk to slaves. Used by Opsview::Connections
and Opsview::Monitoringclusternode.

All functions expect $slave to return the slave port number ($slave->slave_port) and the slave ip
($slave->ip).

=head1 METHODS

=over 4

=item $slave->ssh_command( $remote_command )

Returns the ssh command to talk to $slave, running $remote_command.
Can return as a string or an array - use array if there are quotations in the command
as the string version could lose something in translation to shell

Also, if $remote_command is an array reference, then will make everything here shell friendly. This is
because ssh will lose the quotes once when it makes the remote call. Use this array ref where possible

=cut

# The best test is this:
#   echo '\$SHELL'
#   dosh echo '\$SHELL'
# Output should always be the same
sub ssh_command {
    my ( $self, @args ) = @_;
    my @options = $self->_common_ssh_options( "-p" );
    if ( ref $args[0] eq "ARRAY" ) {
        @args =
          map { $_ = Opsview::Utils->make_shell_friendly($_) } @{ $args[0] };
    }
    my @c = ( "ssh", @options, $self->remote_addr, @args );
    return wantarray ? @c : join( " ", @c );
}

=item $slave->scp_file_out( $source_filename, $target_filename )

Returns the scp command to talk to $slave to transfer source_file to target.

=cut

sub scp_file_out {
    my ( $self, $file, $target ) = @_;
    my @options = $self->_common_ssh_options( "-P" );
    my @c = ( "scp", @options, $file, $self->remote_addr . ":" . $target );
    return wantarray ? @c : join( " ", @c );
}

=item $slave->remote_addr 

Returns the remote address for the slave, based on slave initiation. Could be 127.0.0.1

=cut

sub remote_addr {
    Opsview::Config->slave_initiated ? "127.0.0.1" : shift->ip;
}

sub _common_ssh_options {
    my ( $self, $port_flag ) = @_;
    my @options = ( @ssh_options, "-o", "BatchMode=yes" );
    if ( Opsview::Config->slave_initiated ) {
        my $hostname = $self->name . "-ssh";
        push @options, "-o", "HostKeyAlias=$hostname";
        push @options, $port_flag, $self->slave_port if ($port_flag);
    }
    return @options;
}

=back

=cut

1;
