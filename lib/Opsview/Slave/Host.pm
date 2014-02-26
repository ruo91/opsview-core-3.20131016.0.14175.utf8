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
package Opsview::Slave::HostBase;
use strict;
use Class::Struct;
struct "Opsview::Slave::HostBase" => {
    name                 => '$',
    ip                   => '$',
    primaryclusternode   => '$',
    secondaryclusternode => '$',
};

package Opsview::Slave::Host;
use strict;
use base qw(Opsview::Slave::HostBase);

# Have to hard code - cannot use Opsview::Config as not on slave
my $hosts_file = "/usr/local/nagios/etc/hosts.dat";
sub hosts_file {$hosts_file}

my @hosts;

# This reads on every invoke - only way to make sure is up to date
sub retrieve_all {
    my $class = shift;
    @hosts = ();
    local $/ = "\n"; # This could be changed somewhere above
    open F, $hosts_file or die "Cannot read $hosts_file";
    while (<F>) {
        chop;
        @_ = split( '\t', $_ );
        next unless $_[0];
        my $obj = $class->new(
            name                 => $_[0],
            ip                   => $_[1],
            primaryclusternode   => $_[2],
            secondaryclusternode => $_[3],
        );
        push @hosts, $obj;
    }
    close F;
    return @hosts;
}

1;
