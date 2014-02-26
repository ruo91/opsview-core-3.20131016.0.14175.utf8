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

# Contains common routines for services

package Opsview::ServiceBase;
use strict;
use Opsview::Config;
use Utils::Nagiosgraph;

=item $obj->notifications_enabled

Returns true if is, false if not. Based on other fields

=cut

sub notifications_enabled {
    my $self = shift;
    if   ( $self->notification_options ) { return 1; }
    else                                 { return 0; }
}

=item $self->supports_performance( host=>$host );

Checks filesystem for a directory "$rrddir/$hostname/$servicename", which is the name from the new-style RRDs.
If found, returns 1.

=cut

my $rrddir = Opsview::Config->root_dir . "/var/rrd";

sub supports_performance {
    my $self = shift;
    my %args = @_;
    my $name = $args{name} || $self->name;

    if (  -e "$rrddir/"
        . urlencode( $args{host}->name ) . "/"
        . urlencode($name) )
    {
        return 1;
    }
    return 0;
}

=item $obj->command(fullpath => $prefix, args => $args)

Returns the command string. If fullpath is set, will add $prefix to commands, default not.
If args is set, will override $self->args and use this instead - use this to pass exceptions through.

=cut

sub command {
    my $self = shift;
    my %args = (
        sep => " ",
        @_
    );
    my $command;
    if ( $self->invertresults ) {
        $command = "my_negate$args{sep}";
        $args{sep} = " ";
    }
    my $plugin_args;
    if ( defined $args{args} ) {
        $plugin_args = $args{args};
    }
    else {
        $plugin_args = $self->args;
    }
    if ( defined $plugin_args ) {
        $plugin_args = Opsview::Utils->escape_shriek($plugin_args);
    }
    if ( my $agent = $self->agent ) {
        my $template = $agent->command;
        my $p        = $self->plugin;
        $template =~ s/\$PLUGINNAME\$/$p/;
        my $a = $self->args;
        $template =~ s/\$ARGS\$/$a/;
        $command .= $template;
    }
    else {
        $command .= $self->plugin;
        $command .= $args{sep} . $plugin_args if defined $plugin_args;
    }
    return $command;
}

1;
