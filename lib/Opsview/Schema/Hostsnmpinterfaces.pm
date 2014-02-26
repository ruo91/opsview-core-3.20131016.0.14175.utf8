package Opsview::Schema::Hostsnmpinterfaces;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".hostsnmpinterfaces" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "hostid",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "interfacename",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "active",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 1,
        size          => 11
    },
    "throughput_warning",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "throughput_critical",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "errors_warning",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 30,
    },
    "errors_critical",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 30,
    },
    "discards_warning",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 30,
    },
    "discards_critical",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 30,
    },
    "shortinterfacename",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 52
    },
    "indexid",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 1,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint(
    "hostsnmpinterfaces_hostid_interfacename",
    [ "hostid", "interfacename" ],
);
__PACKAGE__->belongs_to( "host", "Opsview::Schema::Hosts", { id => "hostid" }
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sbvWyjwQ59AlwMP5vRBACg
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

use Opsview;

sub store_column {
    my ( $self, $name, $value ) = @_;

    if ( $name eq "interfacename" && $value ) {
        unless ( $self->shortinterfacename ) {
            my $name          = $value;
            my $invalid_chars = Opsview->invalid_nagios_chars;
            $name =~ s/[$invalid_chars]//g;

            # Strip whitespace at the end. Some interfaces return this which causes problems as Nagios
            # will discard it so the service name no longer matches the Opsview expected name
            # This means that the graphing icon may not display
            $name =~ s/\s+$//g;

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
                  . " WHERE shortinterfacename=? AND hostid = ?";
                my $sth = $self->result_source->storage->dbh->prepare($sql);
                my $result;
                my $hostid = $self->hostid;
                while (
                    (
                        $result = $sth->execute( $basename . ($count), $hostid )
                    ) != "0E0"
                  )
                {
                    $count++;
                }
                $self->shortinterfacename( $basename . $count );
            }
        }
    }
    elsif ( $name =~ /_(critical|warning)$/ ) {
        if ( $value eq "-" ) {
            $value = undef;
        }

        # Doesn't make sense for the default line to have "", so set to undef
        elsif ( $value eq "" && $self->interfacename eq "" ) {
            $value = undef;
        }
    }
    $self->next::method( $name, $value );
}

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

1;
