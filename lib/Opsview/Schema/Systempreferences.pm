package Opsview::Schema::Systempreferences;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".systempreferences" );
__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "default_statusmap_layout",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "default_statuswrl_layout",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "refresh_rate",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "log_notifications",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "log_service_retries",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "log_host_retries",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "log_event_handlers",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "log_initial_states",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "log_external_commands",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "log_passive_checks",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "daemon_dumps_core",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "date_format",
    {
        data_type     => 'ENUM',
        default_value => 'euro',
        is_nullable   => 0,
        size          => 11
    },
    "audit_log_retention",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "host_info_url",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "hostgroup_info_url",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "service_info_url",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "opsview_server_name",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 1,
        size          => 255
    },
    "soft_state_dependencies",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "show_timeline",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 1,
    },
    "smart_hosttemplate_removal",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 1,
    },
    "rancid_email_notification",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "send_anon_data",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 4,
    },
    "uuid",
    {
        data_type     => "CHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 36,
    },
    "netdisco_url",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 1,
        size          => 255,
    },
    "updates_includemajor",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 4,
    },
    "set_downtime_on_host_delete",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 4,
    }
);
__PACKAGE__->set_primary_key( "id" );

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:24E+L+rBEoeFJ5x/7Y4nUQ
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

__PACKAGE__->resultset_class( "Opsview::ResultSet::Systempreferences" );

1;
