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
package Runtime::Schema::OpsviewHostgroupHosts;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "opsview_hostgroup_hosts" );
__PACKAGE__->add_columns(
    "hostgroup_id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "host_object_id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
);

__PACKAGE__->has_many(
    "host_objects",
    "Runtime::Schema::OpsviewHostObjects",
    { "foreign.host_object_id" => "self.host_object_id" },
    { join_type                => "inner" },
);
__PACKAGE__->has_many(
    "host_services",
    "Runtime::Schema::OpsviewHostServices",
    { "foreign.host_object_id" => "self.host_object_id" },
    { join_type                => "inner" },
);

__PACKAGE__->belongs_to(
    "hostgroup",
    "Runtime::Schema::OpsviewHostgroups",
    { "foreign.id" => "self.hostgroup_id" },
    { join_type    => "inner" },
);

__PACKAGE__->has_many(
    "host_contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.host_object_id" },
    { join_type           => "inner" },
);

__PACKAGE__->belongs_to(
    "hoststatus",
    "Runtime::Schema::NagiosHoststatus",
    { "foreign.host_object_id" => "self.host_object_id" },
);

1;
