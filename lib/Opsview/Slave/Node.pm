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
package Opsview::Slave::NodeBase;
use strict;
use Class::Struct;
struct "Opsview::Slave::NodeBase" => {
    name => '$',
    ip   => '$',
    self => '$',
};

package Opsview::Slave::Node;
use strict;
use base qw(Opsview::Slave::NodeBase);

# Have to hard code - Opsview::Config not on slave
my $nodes_file = "/usr/local/nagios/etc/nodes.dat";

my @nodes;

# This reads on every invoke - only way to make sure is up to date
sub retrieve_all {
    my $class = shift;
    @nodes = ();
    local $/ = "\n"; # This could be changed somewhere above
    open F, $nodes_file or die "Cannot read $nodes_file";
    while (<F>) {
        chop;
        @_ = split( '\t', $_ );
        next unless defined $_[0];
        my $obj = $class->new(
            name => $_[0],
            ip   => $_[1],
            self => $_[2],
        );
        push @nodes, $obj;
    }
    close F;
    return @nodes;
}

1;
