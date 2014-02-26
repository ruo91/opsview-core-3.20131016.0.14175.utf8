package Opsview::Schema::Servicechecks;

use strict;
use warnings;

use base qw/Opsview::DBIx::Class Opsview::ServiceBase/;

__PACKAGE__->load_components(qw/+Opsview::DBIx::Class::Common Validation UTF8Columns Core/);
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".servicechecks" );
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
    "checktype",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "plugin",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "args",
    {
        data_type     => "TEXT",
        default_value => "",
        is_nullable   => 0,
        size          => 65535
    },
    "category",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "servicegroup",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "description",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "invertresults",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "notification_options",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
    },
    "notification_interval",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "notification_period",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "check_interval",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
    },
    "retry_check_interval",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
    },
    "check_attempts",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
    },
    "check_freshness",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "stalking",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
    },
    "volatile",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 1,
        size          => 11
    },
    "flap_detection_enabled",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 1,
        size          => 11
    },
    "agent",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "check_period",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "uncommitted",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "freshness_type",
    {
        data_type     => "ENUM",
        default_value => "renotify",
        is_nullable   => 0,
        size          => 9
    },
    "stale_threshold_seconds",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "stale_state",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "stale_text",
    {
        data_type     => "TEXT",
        default_value => undef,
        is_nullable   => 0,
        size          => 65535,
    },
    "markdown_filter",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "attribute",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "cascaded_from",
    {
        data_type      => "integer",
        is_foreign_key => 1,
        is_nullable    => 1
    },
    "alert_from_failure",
    {
        data_type     => "SMALLINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 6
    },
    "event_handler",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255,
    },
    "disable_name_change",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "dependency_level",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "sensitive_arguments",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 1
    },
);
__PACKAGE__->utf8_columns(qw/description/);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->has_many(
    "hostservicechecks",
    "Opsview::Schema::Hostservicechecks",
    { "foreign.servicecheckid" => "self.id" },
    { "join_type"              => "inner" }
);
__PACKAGE__->has_many(
    "hosttemplateservicechecks",
    "Opsview::Schema::Hosttemplateservicechecks",
    { "foreign.servicecheckid" => "self.id" },
    { "join_type"              => "inner" }
);
__PACKAGE__->has_many(
    "keywordservicechecks",
    "Opsview::Schema::Keywordservicechecks",
    { "foreign.servicecheckid" => "self.id" },
);
__PACKAGE__->has_many(
    "servicecheckdependencies_servicecheckids",
    "Opsview::Schema::Servicecheckdependencies",
    { "foreign.servicecheckid" => "self.id" },
);
__PACKAGE__->has_many(
    "servicecheckdependencies_dependencyids",
    "Opsview::Schema::Servicecheckdependencies",
    { "foreign.dependencyid" => "self.id" },
);
__PACKAGE__->has_many(
    "servicecheckhostexceptions",
    "Opsview::Schema::Servicecheckhostexceptions",
    { "foreign.servicecheck" => "self.id" },
);
__PACKAGE__->has_many(
    "servicecheckhosttemplateexceptions",
    "Opsview::Schema::Servicecheckhosttemplateexceptions",
    { "foreign.servicecheck" => "self.id" },
);
__PACKAGE__->belongs_to(
    "check_period",
    "Opsview::Schema::Timeperiods",
    { id => "check_period" },
);
__PACKAGE__->belongs_to( "agent", "Opsview::Schema::Agents", { id => "agent" }
);
__PACKAGE__->belongs_to( "checktype", "Opsview::Schema::Checktypes",
    { id => "checktype" },
);
__PACKAGE__->belongs_to(
    "notification_period",
    "Opsview::Schema::Timeperiods",
    { id => "notification_period" },
);
__PACKAGE__->belongs_to( "plugin", "Opsview::Schema::Plugins",
    { name => "plugin" }
);
__PACKAGE__->belongs_to(
    "servicegroup",
    "Opsview::Schema::Servicegroups",
    { id => "servicegroup" },
);
__PACKAGE__->belongs_to( "attribute", "Opsview::Schema::Attributes",
    { id => "attribute" },
);
__PACKAGE__->has_many(
    "servicechecksnmpactions",
    "Opsview::Schema::Servicechecksnmpactions",
    { "foreign.servicecheckid" => "self.id" },
);
__PACKAGE__->has_many(
    "servicechecksnmpignores",
    "Opsview::Schema::Servicechecksnmpignores",
    { "foreign.servicecheckid" => "self.id" },
);
__PACKAGE__->has_many(
    "servicechecksnmppollings",
    "Opsview::Schema::Servicechecksnmppolling",
    { "foreign.id" => "self.id" },
);
__PACKAGE__->has_many(
    "servicechecktimedoverridehostexceptions",
    "Opsview::Schema::Servicechecktimedoverridehostexceptions",
    { "foreign.servicecheck" => "self.id" },
);
__PACKAGE__->has_many(
    "servicechecktimedoverridehosttemplateexceptions",
    "Opsview::Schema::Servicechecktimedoverridehosttemplateexceptions",
    { "foreign.servicecheck" => "self.id" },
);
__PACKAGE__->has_many(
    "event_handlers",
    "Opsview::Schema::Hostserviceeventhandlers",
    { "foreign.servicecheckid" => "self.id" },
);

__PACKAGE__->might_have(
    "snmppolling",
    "Opsview::Schema::Servicechecksnmppolling",
    { "foreign.id" => "self.id" },
    {
        proxy => [
            qw/oid critical_comparison critical_value warning_value warning_comparison calculate_rate label/
        ]
    }
);

__PACKAGE__->belongs_to(
    "cascaded_from",
    "Opsview::Schema::Servicechecks",
    { id => "cascaded_from" }
);
__PACKAGE__->has_many(
    "cascade_to",
    "Opsview::Schema::Servicechecks",
    { "foreign.cascaded_from" => "self.id" }
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FtokaD23wuOWAVTKjzJhMw
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

__PACKAGE__->many_to_many(
    dependencies => 'servicecheckdependencies_servicecheckids',
    'dependencyid'
);
__PACKAGE__->many_to_many(
    affects => 'servicecheckdependencies_dependencyids',
    'servicecheckid'
);
__PACKAGE__->many_to_many(
    keywords => 'keywordservicechecks',
    'keywordid'
);
__PACKAGE__->many_to_many(
    hosts => 'hostservicechecks',
    'hostid'
);
__PACKAGE__->many_to_many(
    hosttemplates => 'hosttemplateservicechecks',
    'hosttemplateid'
);

__PACKAGE__->resultset_class( "Opsview::ResultSet::Servicechecks" );
__PACKAGE__->resultset_attributes( { order_by => ["name"] } );

# We break the association to cascaded_from servicechecks before the delete
sub delete {
    my ($self) = @_;
    foreach my $c ( $self->cascade_to ) {
        $c->update( { cascaded_from => undef } );
    }
    $self->next::method();
}

sub allowed_columns {
    [
        qw(id name description uncommitted
          checktype plugin args
          servicegroup invertresults
          notification_options notification_interval notification_period
          check_interval retry_check_interval check_attempts check_freshness
          stalking volatile flap_detection_enabled
          check_period freshness_type stale_threshold_seconds stale_state stale_text
          markdown_filter attribute cascaded_from event_handler
          oid critical_comparison critical_value warning_comparison warning_value calculate_rate label
          dependencies keywords
          hosts hosttemplates alert_from_failure sensitive_arguments
          )
    ];
}

sub serialize_override {
    my ( $self, $data, $serialize_columns, $options ) = @_;
}

sub relationships_to_related_class {
    {
        "oid"                 => { type => "might_have", },
        "critical_comparison" => { type => "might_have", },
        "critical_value"      => { type => "might_have", },
        "warning_value"       => { type => "might_have", },
        "warning_comparison"  => { type => "might_have", },
        "calculate_rate"      => { type => "might_have", },
        "label"               => { type => "might_have", },
        "dependencies"        => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecks",
        },
        "check_period" => {
            type  => "single",
            class => "Opsview::Schema::Timeperiods",
        },
        "attribute" => {
            type  => "single",
            class => "Opsview::Schema::Attributes",
        },
        "cascaded_from" => {
            type  => "single",
            class => "Opsview::Schema::Servicechecks",
        },
        "notification_period" => {
            type  => "single",
            class => "Opsview::Schema::Timeperiods",
        },
        "plugin" => {
            type  => "single",
            class => "Opsview::Schema::Plugins",
        },
        "servicegroup" => {
            type  => "single",
            class => "Opsview::Schema::Servicegroups",
        },
        "checktype" => {
            type  => "single",
            class => "Opsview::Schema::Checktypes",
        },
        "keywords" => {
            type  => "multi",
            class => "Opsview::Schema::Keywords"
        },
        "hosts" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts"
        },
        "hosttemplates" => {
            type  => "multi",
            class => "Opsview::Schema::Hosttemplates"
        },
    };
}

sub new {
    my ( $class, $attrs ) = @_;
    unless ( $attrs->{check_period} ) {
        $attrs->{check_period} = 1;
    }
    my $new = $class->next::method($attrs);
    return $new;
}

use Opsview::Utils::Time;

sub store_column {
    my ( $self, $name, $value ) = @_;
    if ( $name eq "stale_threshold_seconds" ) {
        eval { $value = Opsview::Utils::Time->jira_duration_to_seconds($value) };
        if ($@) {
            die( "Error with jira duration input for $name: $value\n" );
        }
    }
    elsif ( $name eq "name" ) {
        $value =~ s/ +$//;
    }
    $self->next::method( $name, $value );
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required           => [qw/name checktype/],
        optional           => [qw/notification_options/],
        constraint_methods => {
            name                 => qr/^[\w\.\/-][\w \.\/-]{0,62}$/,
            checktype            => qr/^\d+$/,
            notification_options => qr/^([wcurfsn])(,[wcurfs])*$/,
        },
        msgs => { format => "%s", },
    };
}

# this is probably bad because plugin syntax is held in the model
# Returns the args
sub check_snmp_threshold_args {
    my $self = shift;
    my @args;
    if ( $self->critical_comparison eq "eq" ) {
        push @args, "-s '" . $self->critical_value . "'";
    }
    elsif ( $self->critical_comparison eq "ne" ) {
        push @args, "-s '" . $self->critical_value . "' --invert-search";
    }
    elsif ( $self->critical_comparison eq "regex" ) {
        push @args, "-r '" . $self->critical_value . "'";
    }
    elsif ( defined $self->critical_value ) {
        if ( $self->critical_comparison eq "==" ) {
            push @args,
              "-c " . $self->critical_value . ":" . $self->critical_value;
        }
        elsif ( $self->critical_comparison eq "<" ) {
            push @args, "-c " . $self->critical_value . ":";
        }
        elsif ( $self->critical_comparison eq ">" ) {
            push @args, "-c :" . $self->critical_value;
        }
    }
    if ( defined $self->warning_value ) {
        if ( $self->warning_comparison eq "==" ) {
            push @args,
              "-w " . $self->warning_value . ":" . $self->warning_value;
        }
        elsif ( $self->warning_comparison eq "<" ) {
            push @args, "-w " . $self->warning_value . ":";
        }
        elsif ( $self->warning_comparison eq ">" ) {
            push @args, "-w :" . $self->warning_value;
        }
    }
    return join( " ", @args );
}

sub category_and_name {
    my $self = shift;
    return $self->servicegroup->name . ": " . $self->name;
}

# Class::DBI compatibility - TODO: convert to DBIx::Class
sub class_dbi_obj {
    my $self = shift;
    unless ( exists $self->{opsview_stash}->{class_dbi_obj} ) {
        $self->{opsview_stash}->{class_dbi_obj} =
          Opsview::Servicecheck->retrieve( $self->id );
    }
    return $self->{opsview_stash}->{class_dbi_obj};
}

sub count_all_exceptions_by_service {
    my ( $self, @args ) = @_;
    return $self->class_dbi_obj->count_all_exceptions_by_service(@args);
}

sub list_keywords {
    my ( $self, $sep ) = @_;
    $sep ||= ",";
    return join( $sep, map { $_->name } $self->keywords );
}

sub set_dependency_level {
    my ( $object, $current_level ) = @_;
    foreach my $parent ( $object->dependencies ) {
        $parent->set_dependency_level( $current_level + 1 );
    }

    # We also consider the cascaded_from field, because if this is set, the cascade down needs to
    # be at least 1 level higher than the service check itself
    if ( my $cascaded_from = $object->cascaded_from ) {
        if ( $cascaded_from->checktype->id == 1 ) {
            $cascaded_from->set_dependency_level( $current_level + 1 );
        }
    }
    $object->update( { dependency_level => $current_level } )
      if ( $object->dependency_level < $current_level );
}

# Use this to check for checktype == active.
# We ignore cascading checks for the moment
sub is_active_checktype {
    my ($self) = @_;
    if ( $self->checktype->id == 1 ) {
        return 1;
    }
    return 0;
}

1;
