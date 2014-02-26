package Opsview::Schema::Timeperiods;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".timeperiods" );
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
        size          => 128
    },
    "alias",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "sunday",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 48,
    },
    "monday",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 48,
    },
    "tuesday",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 48,
    },
    "wednesday",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 48,
    },
    "thursday",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 48,
    },
    "friday",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 48,
    },
    "saturday",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 48,
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
__PACKAGE__->has_many(
    "notificationprofiles",
    "Opsview::Schema::Notificationprofiles",
    { "foreign.notification_period" => "self.id" },
);
__PACKAGE__->has_many( "host_check_periods", "Opsview::Schema::Hosts",
    { "foreign.check_period" => "self.id" },
);
__PACKAGE__->has_many( "host_notification_periods", "Opsview::Schema::Hosts",
    { "foreign.notification_period" => "self.id" },
);
__PACKAGE__->has_many(
    "servicecheck_check_periods",
    "Opsview::Schema::Servicechecks",
    { "foreign.check_period" => "self.id" },
);
__PACKAGE__->has_many(
    "servicecheck_notification_periods",
    "Opsview::Schema::Servicechecks",
    { "foreign.notification_period" => "self.id" },
);
__PACKAGE__->has_many(
    "host_timed_exceptions",
    "Opsview::Schema::Servicechecktimedoverridehostexceptions",
    { "foreign.timeperiod" => "self.id" },
);
__PACKAGE__->has_many(
    "hosttemplate_timed_exceptions",
    "Opsview::Schema::Servicechecktimedoverridehosttemplateexceptions",
    { "foreign.timeperiod" => "self.id" },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nH2FlTfEQPVvHdswl3fhEQ
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

use overload
  '""'     => sub { shift->name },
  fallback => 1;

__PACKAGE__->resultset_class( "Opsview::ResultSet::Timeperiods" );
__PACKAGE__->resultset_attributes( { order_by => ["name"] } );

sub allowed_columns {
    [
        qw(id name alias
          monday tuesday wednesday thursday friday saturday sunday
          host_check_periods host_notification_periods
          servicecheck_check_periods servicecheck_notification_periods
          uncommitted
          )
    ];

    # Am not serializing these two for the moment.
    # I think the problem is a recursive one - should ask each object to serialize itself and then related objects are
    # told to serialize themselves with a different level setting. Will look into this after converting other classes
    #hosttemplate_timed_exceptions
}

sub relationships_to_related_class {
    {
        "host_check_periods" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts",
        },
        "host_notification_periods" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts",
        },
        "servicecheck_check_periods" => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecks",
        },
        "servicecheck_notification_periods" => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecks",
        },
        "host_timed_exceptions" => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecktimedoverridehostexceptions",
        },
        "hosttemplate_timed_exceptions" => {
            type => "multi",
            class =>
              "Opsview::Schema::Servicechecktimedoverridehosttemplateexceptions",
        },
    };
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

my $timeperiod_regex = qr/^\d\d\:\d\d-\d\d:\d\d(,\d\d:\d\d-\d\d:\d\d)*$/;

sub get_dfv_profile {
    return {
        required => [qw/name/],
        optional =>
          [qw/alias monday tuesday wednesday thursday friday saturday sunday/],
        constraint_methods => {
            name      => qr/^[\w\. \/-]{1,128}$/,
            alias     => qr/^[\w\., :\/-]{1,128}$/,
            monday    => $timeperiod_regex,
            tuesday   => $timeperiod_regex,
            wednesday => $timeperiod_regex,
            thursday  => $timeperiod_regex,
            friday    => $timeperiod_regex,
            saturday  => $timeperiod_regex,
            sunday    => $timeperiod_regex,
        },
        msgs => { format => "%s", },
    };
}

1;
