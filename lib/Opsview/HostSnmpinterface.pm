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

package Opsview::HostSnmpinterface;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 1917 $';

__PACKAGE__->table( "hostsnmpinterfaces" );

__PACKAGE__->columns( Primary => qw/id/, );

__PACKAGE__->columns( Essential =>
      qw/hostid interfacename shortinterfacename active throughput_warning throughput_critical indexid/,
);

__PACKAGE__->has_a( hostid => "Opsview::Host" );

__PACKAGE__->initial_columns(qw/interfacename hostid/);

# Trigger to set the short interface name
#
# description used for the snmp interface as set in nagconfgen.pl for
# service checks are
#   first 10 chars of name of id 0 in embedded service table
#   plus ": "
#   plus the rest of the short interface name
# Max length for description of service is 64 chars
#
# This trigger ensures the shortname is therefore unique
#
my $length_limit = 52;

sub before_create {
    my $self = shift;

    unless ( $self->{shortinterfacename} ) {
        my $name          = $self->interfacename;
        my $invalid_chars = Opsview->invalid_nagios_chars;
        $name =~ s/[$invalid_chars]//g;
        if ( length($name) <= $length_limit ) {
            $self->shortinterfacename($name);
        }
        else {
            my $basename = substr( $name, 0, $length_limit - 3 );
            $basename .= " ";
            my $count = 1;
            my $sql =
                "SELECT shortinterfacename FROM "
              . $self->table
              . " WHERE shortinterfacename=? AND hostid = "
              . $self->{hostid};
            my $sth = $self->db_Main->prepare($sql);
            my $result;
            while (
                ( $result = $sth->execute( $basename . ($count) ) ) != "0E0" )
            {
                $count++;
            }
            $self->shortinterfacename( $basename . $count );
        }
    }
}

__PACKAGE__->add_trigger( before_create => \&before_create );

# Returns ($interfacename, $index)
# Need this because duplicated interfaces will have the index id removed
sub actual_interface_name_and_index {
    my ($self) = @_;
    if ( my $i = $self->indexid ) {
        my $iname = $self->interfacename;
        $iname =~ s/-0*$i$//;
        return ( $iname, $i );
    }
    else {
        return ( $self->interfacename, undef );
    }
}

# Convenience function. Simulates the hash info from a query_host
sub duplicatename { shift->indexid > 0 }

=head1 NAME

Opsview::HostSnmpinterface - Accessing hostsnmpinterfaces table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview hostsnmpinterfaces information

=head1 METHODS

=over 4

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
