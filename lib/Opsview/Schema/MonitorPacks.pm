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
package Opsview::Schema::MonitorPacks;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

=head1 NAME

Opsview::Schema::Result::MonitorPack

=cut

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".monitor_packs" );

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 alias

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 version

  data_type: 'varchar'
  is_nullable: 0
  size: 16

=head2 status

  data_type: 'enum'
  extra: {list => ["OK","NOTICE","FAILURE"]}
  is_nullable: 0

=head2 message

  data_type: 'text'
  is_nullable: 0

=head2 dependencies

  data_type: 'text'
  is_nullable: 0

=head2 created

  data_type: 'integer'
  is_nullable: 0

=head2 updated

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0
    },
    "name",
    {
        data_type   => "varchar",
        is_nullable => 0,
        size        => 128
    },
    "alias",
    {
        data_type   => "varchar",
        is_nullable => 0,
        size        => 255
    },
    "version",
    {
        data_type   => "varchar",
        is_nullable => 0,
        size        => 16
    },
    "status",
    {
        data_type     => "enum",
        default_value => "INSTALLING",
        extra       => { list => [ "OK", "NOTICE", "FAILURE", "INSTALLING" ] },
        is_nullable => 0,
    },
    "message",
    {
        data_type   => "text",
        is_nullable => 0
    },
    "dependencies",
    {
        data_type   => "text",
        is_nullable => 0
    },
    "created",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "updated",
    {
        data_type   => "integer",
        is_nullable => 0
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );

# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-03-22 12:10:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CQfprh+ZeQgyWFf6AJJAzQ

__PACKAGE__->resultset_class( "Opsview::ResultSet::MonitorPacks" );

sub insert {
    my ( $self, @args ) = @_;
    $self->created( time() );
    $self->next::method(@args);
}

sub update {
    my ( $self, @args ) = @_;
    $self->updated( time() );
    $self->next::method(@args);
}

1;
