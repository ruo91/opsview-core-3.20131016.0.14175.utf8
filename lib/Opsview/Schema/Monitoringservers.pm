package Opsview::Schema::Monitoringservers;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".monitoringservers" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "name",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 64
    },
    "host",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11,
        accessor      => "_host"
    },
    "role",
    {
        data_type     => "ENUM",
        default_value => "Slave",
        is_nullable   => 1,
        size          => 6
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
        default_value => 1,
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
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->has_many( "monitors", "Opsview::Schema::Hosts",
    { "foreign.monitored_by" => "self.id" },
);
__PACKAGE__->has_many(
    "nodes",
    "Opsview::Schema::Monitoringclusternodes",
    { "foreign.monitoringcluster" => "self.id" },
);
__PACKAGE__->belongs_to( "_host", "Opsview::Schema::Hosts", { id => "host" } );
__PACKAGE__->has_many(
    "reloadmessages",
    "Opsview::Schema::Reloadmessages",
    { "foreign.monitoringcluster" => "self.id" },
);
__PACKAGE__->has_many(
    "roles_monitoringservers",
    "Opsview::Schema::RolesMonitoringservers",
    { "foreign.monitoringserverid" => "self.id" },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DV2xu6+bnEGM6lpik/RXHw
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

__PACKAGE__->resultset_class( "Opsview::ResultSet::Monitoringservers" );

__PACKAGE__->many_to_many(
    roles => "roles_monitoringservers",
    "roleid"
);

use overload
  '""'     => sub { shift->id },
  fallback => 1;

# Ignore host for the moment, as 3.11 will remove this column
sub synchronise_ignores { { host => 1 } }

# Bit of dirty serialization here because Opsview Master doesn't have a monitoringclusternode - this will be
# changed in 3.11
sub serialize_override {
    my ( $self, $data, $serialize_columns, $options ) = @_;
    if ( delete $serialize_columns->{nodes} ) {
        $data->{nodes} = [];
        my @hosts =
          ( $self->is_master ? ( $self->host ) : map { $_->host }
              $self->nodes );
        foreach my $h (@hosts) {
            my $hostinfo = { name => $h->name };
            if ( $options->{ref_prefix} ) {
                $hostinfo->{ref} =
                  join( "/", $options->{ref_prefix}, "host", $h->id );
            }
            my $hash = { host => $hostinfo };
            push @{ $data->{nodes} }, $hash;
        }
    }
}

sub allowed_columns {
    [
        qw(id name
          activated
          roles
          monitors
          nodes
          passive
          uncommitted
          )
    ];
}

sub relationships_to_related_class {
    {
        "roles" => {
            type  => "multi",
            class => "Opsview::Schema::Roles",
        },
        "monitors" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts",
        },
        "nodes" => {
            type  => "multi",
            class => "Opsview::Schema::Monitoringclusternodes",
        },
    };
}

=begin ignore this for 3.10, but re-introduce for 3.11

sub delete {
    my ( $self, @args ) = @_;
    die "Cannot delete master" if $self->is_master;

    # Move all hosts monitored by this cluster to master
    my $rs = $self->monitors;
    while ( my $host = $rs->next ) {
        $host->update( { monitored_by => 1 } );
    }

    $self->result_source->schema->resultset("Monitoringservers")->write_connections_file;
    return $self->next::method(@args);
}

=cut

sub mshosts {
    my $self = shift;
    if ( $self->is_master ) {
        return ( $self->host );
    }
    else {
        return map { $_->host } $self->nodes;
    }
}

sub is_master {
    shift->id == 1;
}

sub is_slave { shift->id > 1 }

sub is_active {
    my $self = shift;
    ( $self->is_master || ( $self->activated && $self->monitors->count > 0 ) )
      ? 1
      : 0;
}

sub is_passive {
    my $self = shift;
    ( $self->is_master || !$self->passive ) ? 0 : 1;
}

# Use this to override host expansion, which is changed for slave clusters
sub host {
    my $self = shift;
    if ( $self->is_slave ) {
        return $self->nodes->first->host;
    }
    else {
        return $self->_host(@_);
    }
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required           => [qw/name/],
        constraint_methods => { name => qr/^[\w\. \+_-]{1,63}$/, },
        msgs               => { format => "%s", },
    };
}

1;
