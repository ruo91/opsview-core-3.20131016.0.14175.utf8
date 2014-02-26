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
package Runtime::Schema::OpsviewPerformanceMetrics;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "opsview_performance_metrics" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "service_object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "hostname",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 64,
    },
    "servicename",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "metricname",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 64,
    },
    "uom",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 1,
        size          => 64,
    },
);

__PACKAGE__->set_primary_key( "id" );

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-09-19 02:55:33

__PACKAGE__->has_many(
    "contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.service_object_id" },
    { join_type           => "inner" },
);
__PACKAGE__->has_many(
    "keywords",
    "Runtime::Schema::OpsviewViewports",
    { "foreign.object_id" => "self.service_object_id" },
    { join_type           => "inner" },
);
__PACKAGE__->belongs_to(
    "servicestatus",
    "Runtime::Schema::NagiosServicestatus",
    { "foreign.service_object_id" => "self.service_object_id" },
    { join_type                   => "inner" },
);
__PACKAGE__->belongs_to(
    "object",
    "Runtime::Schema::OpsviewHostObjects",
    { "foreign.object_id" => "self.service_object_id" },
    { join_type           => "inner" }
);

__PACKAGE__->resultset_class( "Runtime::ResultSet::OpsviewPerformanceMetrics"
);

1;
