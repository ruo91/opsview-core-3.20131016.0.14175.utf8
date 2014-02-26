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
package Runtime::Schema::NagiosProgramstatus;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table( "nagios_programstatus" );
__PACKAGE__->add_columns(
    "programstatus_id",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "instance_id",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "status_update_time",
    {
        data_type     => "datetime",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
        timezone      => "UTC",
    },
    "program_start_time",
    {
        data_type     => "datetime",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
        timezone      => "UTC",
    },
    "program_end_time",
    {
        data_type     => "datetime",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
        timezone      => "UTC",
    },
    "is_currently_running",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "process_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "daemon_mode",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "last_command_check",
    {
        data_type     => "datetime",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
        timezone      => "UTC",
    },
    "last_log_rotation",
    {
        data_type     => "datetime",
        default_value => "0000-00-00 00:00:00",
        is_nullable   => 0,
        size          => 19,
        timezone      => "UTC",
    },
    "notifications_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "active_service_checks_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "passive_service_checks_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "active_host_checks_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "passive_host_checks_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "event_handlers_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "flap_detection_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "failure_prediction_enabled",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "process_performance_data",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "obsess_over_hosts",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "obsess_over_services",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6
    },
    "modified_host_attributes",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "modified_service_attributes",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "global_host_event_handler",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "global_service_event_handler",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
);
__PACKAGE__->set_primary_key( "programstatus_id" );
__PACKAGE__->add_unique_constraint( "instance_id", ["instance_id"] );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
