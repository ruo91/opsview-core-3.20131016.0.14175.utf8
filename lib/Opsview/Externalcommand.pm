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

package Opsview::Externalcommand;
use strict;
use warnings;

my $master_cmdfile = "/usr/local/nagios/var/rw/nagios.cmd";
my $slave_cmdfile  = "/usr/local/nagios/var/slave_commands.cache";

=head1 NAME

Opsview::Externalcommand - Interface to write to Nagios' external command file for both

=head1 DESCRIPTION

Writes an external command to Nagios' command file for both the master
and slave servers

=head1 METHODS

=over 4

=item Opsview::Externalcommand->new( command => "DISABLE_HOSTGROUP_SVC_NOTIFICATIONS",
	args => "hostgroup1",
	);

Creates the object optionally specifying the command and arguments.  Returns the object.

=cut

sub new {
    my $class = shift;
    my $self  = {
        _command => "",
        _args    => "",
        _type    => "",
    };
    bless( $self, $class );
    $self->_init(@_);
    return $self;
}

sub _init {
    my $self = shift;
    if (@_) {
        my %args = @_;
        foreach ( keys(%args) ) {
            $self->$_( $args{$_} );
        }
    }
}

=item $obj->command($command);

=item $obj->command();

If C<$command> is given sets and returns the command, else just returns the command.

=cut

sub command {
    my $self = shift;
    $self->{_command} = $_[0] if ( $_[0] );
    return $self->{_command};
}

=item $obj->args($args);

=item $obj->args();

If C<$args> is given sets and returns the arguments, else just returns the arguments.

=cut

sub args {
    my $self = shift;
    my $arg_list;
    if ( ref( $_[0] ) eq "ARRAY" ) {
        $arg_list .= $_ . ";" foreach ( @{ $_[0] } );
    }
    else {
        foreach my $arg (@_) {
            if ( !ref($arg) ) {
                $arg_list .= $arg . ";";
            }
            elsif ( ref($arg) eq "ARRAY" ) {
                $arg_list .= $_ . ";" foreach ($arg);
            }
        }
    }
    $self->{_args} = $arg_list if ($arg_list);
    $self->{_args} =~ s/;$// if ( $self->{_args} );
    return $self->{_args};
}

sub _write_to_file {
    my ( $self, $filename ) = @_;
    {
        local $SIG{ALRM} =
          sub { die "Cannot send Nagios external command to $filename\n" };
        alarm(10);
        my $method = ">";
        $method = ">>" if ( -f $filename );
        unless ( open F, $method, $filename ) {
            die( "Cannot open file $filename: $!\n" );
            alarm(0);
            return undef;
        }
        alarm(0);
    }

    my $out;
    if ( $self->{_type} eq "master" ) {
        $out = "[" . time . "] ";
    }
    $out .= $self->command;
    if ( $self->args ) {
        $out .= ";" . $self->args;
    }

    # Stop linefeeds from being entered
    if ( $out =~ /\n/ ) {
        die( "Command contains invalid characters\n" );
    }

    {
        local $SIG{ALRM} =
          sub { die "Cannot send Nagios external command to $filename\n" };
        alarm(10);
        print F $out . "\n";
        close F;
        alarm(0);
    }
    return 1;
}

=item $cmd->send_to_master

Submits the chosen command to the master server. Will do timeouts and 
checks. Returns true if successfully sent.  Will die
if there are any problems.

=cut

sub send_to_master {
    my $self = shift;
    $self->{_type} = "master";

    return $self->_write_to_file($master_cmdfile);
}

=item $cmd->submit

Alias to $cmd->send_to_all

=cut

sub submit {
    my $self = shift;

    return $self->send_to_all;
}

=item $cmd-send_to_slaves

Submits the chosen command to C<opsviewd> for sending on to the slave
servers. Will do timeouts and checks. Returns true if successfully 
sent.  Will die if there are any problems.

=cut

sub send_to_slaves {
    my $self = shift;
    $self->{_type} = "slave";

    return $self->_write_to_file($slave_cmdfile);
}

=item $cmd->send_to_all

Calls both C<$cmd->send_to_master> and C<$cmd->send_to_slaves>.  If either
fails will die (if the slave fails the master may have 
received the command successfully).

=cut

sub send_to_all {
    my $self = shift;

    return undef unless ( $self->send_to_master && $self->send_to_slaves );
    return 1;
}

# routines to help with testing, to override files written to
sub master_file {
    my ( $self, $filename ) = @_;
    $master_cmdfile = $filename if $filename;
    return $master_cmdfile;
}

sub slave_file {
    my ( $self, $filename ) = @_;
    $slave_cmdfile = $filename if $filename;
    return $slave_cmdfile;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
