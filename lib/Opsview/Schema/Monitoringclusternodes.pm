package Opsview::Schema::Monitoringclusternodes;

use strict;
use warnings;

use Opsview::Sshcommands;
use base 'Opsview::DBIx::Class', 'Opsview::Sshcommands';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".monitoringclusternodes" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "monitoringcluster",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "host",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "activated",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "passive",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "uncommitted",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "monitoringcluster",
    [ "monitoringcluster", "host" ]
);
__PACKAGE__->belongs_to(
    "monitoringcluster",
    "Opsview::Schema::Monitoringservers",
    { id => "monitoringcluster" },
);
__PACKAGE__->belongs_to( "host", "Opsview::Schema::Hosts", { id => "host" } );

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:J5UQ6aQzyB8yLnEHzuNGpA
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

# You can replace this text with custom content, and it will be preserved on regeneration

# Stringification required for Set::Cluster to be deterministic (otherwise uses stringification of
# object where order will change based on the address space used for object)
use overload
  '""'     => sub { shift->id },
  fallback => 1;
sub name { shift->host->name }
sub ip   { shift->host->ip }

sub slave_port {
    my $self = shift;
    if ( Opsview::Config->slave_initiated ) {
        return ( Opsview::Config->slave_base_port + $self->id );
    }
    else {
        return 22;
    }
}

sub is_activated { shift->monitoringcluster->is_activated }

sub short_name {
    my $self = shift;
    return "node" . $self->id;
}

sub allowed_columns {
    [
        qw(host
          )
    ];
}

1;
