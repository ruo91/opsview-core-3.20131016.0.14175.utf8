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

# This needs to be light weight - no db access!
package Opsview::ConnectionsBase;
use strict;
use Class::Struct;
struct "Opsview::ConnectionsBase" => {
    name       => '$',
    active     => '$',
    ip         => '$',
    slave_port => '$',
};

package Opsview::Connections;
use strict;
use Opsview::Config;
use Opsview::Sshcommands;
use base qw(Opsview::ConnectionsBase Opsview::Sshcommands);

my $connections_file = Opsview::Config->root_dir . "/etc/connections.dat";
sub connections_file {$connections_file}

my @slaves;

# This reads on every invoke - only way to make sure is up to date
sub slaves {
    my $class = shift;
    @slaves = ();
    local $/ = "\n"; # This could be changed somewhere above
    open F, $connections_file or die "Cannot read $connections_file";
    while (<F>) {
        chop;
        @_ = split( ':', $_ );
        next unless $_[2];
        my $obj = $class->new(
            name       => $_[0],
            active     => $_[1],
            ip         => $_[2],
            slave_port => $_[3],
        );
        push @slaves, $obj;
    }
    close F;
    return @slaves;
}

1;
