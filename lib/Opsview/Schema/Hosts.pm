package Opsview::Schema::Hosts;

use strict;
use warnings;
use Opsview::Config;
use Try::Tiny;
use Opsview::Externalcommand;

use base "Opsview::DBIx::Class", "Opsview::HostBase";

# Use this to control whether to use caching or not
# We only cache the last host as nagconfgen will iterate through X services
# on the same host, so we save further lookups
our $CACHE_HOST_ATTRIBUTES = 0;
my $cache_host_attributes_last_id         = 0;
my $cache_host_attributes_last_attributes = {};

__PACKAGE__->load_components(
    qw/+Opsview::DBIx::Class::Common Validation UTF8Columns Core/);
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".hosts" );
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
    "ip",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255,
        accessor      => "_ip"
    },
    "alias",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "notification_interval",
    {
        data_type     => "INT",
        default_value => 60,
        is_nullable   => 0,
        size          => 11
    },
    "hostgroup",
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
    "check_interval",
    {
        data_type     => "VARCHAR",
        default_value => "0",
        is_nullable   => 1,
        size          => 16,
    },
    "retry_check_interval",
    {
        data_type     => "VARCHAR",
        default_value => "1",
        is_nullable   => 1,
        size          => 16,
    },
    "check_attempts",
    {
        data_type     => "VARCHAR",
        default_value => "2",
        is_nullable   => 1,
        size          => 16,
    },
    "icon",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "enable_snmp",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "snmp_community",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255,
    },
    "notification_options",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
    },
    "notification_period",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "check_command",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "http_admin_url",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "http_admin_port",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
    },
    "monitored_by",
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
    "other_addresses",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255
    },
    "snmp_version",
    {
        data_type     => "ENUM",
        default_value => "2c",
        is_nullable   => 1,
        size          => 2
    },
    "snmp_port",
    {
        data_type     => "integer",
        default_value => "161",
        is_nullable   => 0,
        size          => 5
    },
    "snmpv3_username",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 128
    },
    "snmpv3_authprotocol",
    {
        data_type     => "ENUM",
        default_value => undef,
        is_nullable   => 1,
        size          => 3
    },
    "snmpv3_authpassword",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 128
    },
    "snmpv3_privprotocol",
    {
        data_type     => "ENUM",
        default_value => undef,
        is_nullable   => 1,
        size          => 6
    },
    "snmpv3_privpassword",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 128
    },
    "snmptrap_tracing",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 1,
        size          => 11
    },
    "use_rancid",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 1,
        size          => 11
    },
    "rancid_vendor",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 1,
        size          => 11
    },
    "rancid_username",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "rancid_password",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 255,
    },
    "rancid_connection_type",
    {
        data_type     => "ENUM",
        default_value => "ssh",
        is_nullable   => 1,
        size          => 6
    },
    "rancid_autoenable",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 1,
        size          => 11
    },
    "use_nmis",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 1,
        size          => 11
    },
    "nmis_node_type",
    {
        data_type     => "ENUM",
        default_value => "router",
        is_nullable   => 1,
        size          => 6
    },
    "flap_detection_enabled",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "use_mrtg",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "tidy_ifdescr_level",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "snmp_max_msg_size",
    {
        data_type     => "SMALLINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 6,
        extra         => { unsigned => 1 }
    },
    "snmp_extended_throughput_data",
    {
        data_type     => "TINYINT",
        default_value => 0,
        is_nullable   => 0,
        size          => 4
    },
    "event_handler",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 255,
    },
);
__PACKAGE__->utf8_columns(qw/name alias/);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );
__PACKAGE__->has_many(
    "hosthosttemplates", "Opsview::Schema::Hosthosttemplates",
    { "foreign.hostid" => "self.id" }, { order_by => ["priority"] }
);
__PACKAGE__->has_many( "hostinfoes", "Opsview::Schema::Hostinfo",
    { "foreign.id" => "self.id" },
);
__PACKAGE__->belongs_to(
    "rancid_vendor",
    "Opsview::Schema::RancidVendors",
    { id => "rancid_vendor" },
);
__PACKAGE__->belongs_to(
    "check_command",
    "Opsview::Schema::Hostcheckcommands",
    { id => "check_command" },
);
__PACKAGE__->belongs_to( "hostgroup", "Opsview::Schema::Hostgroups",
    { id => "hostgroup" },
);
__PACKAGE__->belongs_to( "icon", "Opsview::Schema::Icons", { name => "icon" }
);
__PACKAGE__->belongs_to(
    "monitored_by",
    "Opsview::Schema::Monitoringservers",
    { id => "monitored_by" },
);
__PACKAGE__->belongs_to(
    "notification_period",
    "Opsview::Schema::Timeperiods",
    { id => "notification_period" },
);
__PACKAGE__->has_many(
    "hostservicechecks",
    "Opsview::Schema::Hostservicechecks",
    { "foreign.hostid" => "self.id" },
);
__PACKAGE__->has_many(
    "snmpinterfaces", "Opsview::Schema::Hostsnmpinterfaces",
    { "foreign.hostid" => "self.id" }, { order_by => "interfacename" }
);
__PACKAGE__->has_many(
    "keywordhosts",
    "Opsview::Schema::Keywordhosts",
    { "foreign.hostid" => "self.id" },
);
__PACKAGE__->has_many(
    "monitoringclusternodes",
    "Opsview::Schema::Monitoringclusternodes",
    { "foreign.host" => "self.id" },
);
__PACKAGE__->has_many(
    "monitoringservers",
    "Opsview::Schema::Monitoringservers",
    { "foreign.host" => "self.id" },
);
__PACKAGE__->has_many(
    "parents_hostids", "Opsview::Schema::Parents",
    { "foreign.hostid" => "self.id" }, { join_type => "inner" }
);
__PACKAGE__->has_many(
    "parents_parentids", "Opsview::Schema::Parents",
    { "foreign.parentid" => "self.id" }, { join_type => "inner" }
);
__PACKAGE__->has_many(
    "exceptions",
    "Opsview::Schema::Servicecheckhostexceptions",
    { "foreign.host" => "self.id" },
);
__PACKAGE__->has_many(
    "timed_exceptions",
    "Opsview::Schema::Servicechecktimedoverridehostexceptions",
    { "foreign.host" => "self.id" },
);
__PACKAGE__->has_many(
    "event_handlers",
    "Opsview::Schema::Hostserviceeventhandlers",
    { "foreign.hostid" => "self.id" },
);
__PACKAGE__->has_many(
    "snmpwalkcaches",
    "Opsview::Schema::Snmpwalkcache",
    { "foreign.hostid" => "self.id" },
);
__PACKAGE__->belongs_to(
    "check_period",
    "Opsview::Schema::Timeperiods",
    { id => "check_period" },
);
__PACKAGE__->has_many(
    "hostattributes",
    "Opsview::Schema::HostAttributes",
    { "foreign.host" => "self.id" },
    {
        join     => "attribute",
        order_by => [ "attribute.name", "me.value" ]
    }
);

__PACKAGE__->might_have(
    "info", "Opsview::Schema::Hostinfo",
    { "foreign.id" => "self.id" },
    { proxy        => [qw/information/] }
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-09-17 13:24:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zFGJlC44seMfYZ7XAympcQ
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
    hosttemplates => 'hosthosttemplates',
    'hosttemplateid'
);
__PACKAGE__->many_to_many(
    servicechecks => 'hostservicechecks',
    'servicecheckid'
);
__PACKAGE__->many_to_many(
    parents => 'parents_hostids',
    'parentid'
);
__PACKAGE__->many_to_many(
    children => 'parents_parentids',
    'hostid'
);
__PACKAGE__->many_to_many(
    keywords => 'keywordhosts',
    'keywordid'
);

__PACKAGE__->resultset_class( "Opsview::ResultSet::Hosts" );

# This causes problems for joins. I think this is a bug in DBIx::Class, but don't know where yet
# Currently up to 0.08123
# Leaving this in for the moment, because join at the list pages is not done
__PACKAGE__->resultset_attributes( { order_by => { "-asc" => "name" } } );

# You can replace this text with custom content, and it will be preserved on regeneration
use overload
  '""'     => sub { shift->id },
  fallback => 1;

sub allowed_columns {
    [
        qw(id name ip other_addresses monitored_by
          alias parents hostgroup check_command icon keywords check_period
          check_interval check_attempts retry_check_interval hosttemplates
          notification_interval notification_options notification_period
          flap_detection_enabled
          enable_snmp snmp_version snmp_port snmp_community snmpv3_username snmpv3_authprotocol snmpv3_authpassword snmpv3_privpassword snmpv3_privprotocol snmpv3_privpassword
          use_rancid rancid_vendor rancid_username rancid_password rancid_connection_type
          use_nmis nmis_node_type use_mrtg tidy_ifdescr_level snmp_max_msg_size
          snmp_extended_throughput_data
          servicechecks
          hostattributes
          uncommitted
          event_handler
          )
    ];
}

sub serialize_override {
    my ( $self, $data, $serialize_columns, $options ) = @_;

    if ( delete $serialize_columns->{servicechecks} ) {

        # Get related information
        my %event_handlers =
          map { ( $_->servicecheck->id => $_ ) } $self->event_handlers;
        my %exceptions =
          map { ( $_->servicecheck->id => $_ ) } $self->exceptions;
        my %timed_exceptions =
          map { ( $_->servicecheck->id => $_ ) } $self->timed_exceptions;

        $data->{servicechecks} = [];

        # This is $self->hostservicechecks, not $self->servicechecks because want the relationship
        # not the related object
        foreach my $rel (
            $self->hostservicechecks(
                {},
                {
                    join     => "servicecheckid",
                    order_by => "servicecheckid.name",
                    columns  => [
                        qw/servicecheckid.name servicecheckid.id remove_servicecheck/
                    ]
                }
            )
          )
        {
            my $hash = { name => $rel->servicecheckid->name };
            if ( $options->{ref_prefix} ) {
                $hash->{ref} = join( "/",
                    $options->{ref_prefix},
                    "servicecheck", $rel->servicecheckid->id );
            }
            $hash->{remove_servicecheck} = $rel->remove_servicecheck;

            if ( my $ev = $event_handlers{ $rel->servicecheckid->id } ) {
                $hash->{event_handler} = $ev->event_handler;
            }
            else {
                $hash->{event_handler} = undef;
            }

            if ( my $ex = $exceptions{ $rel->servicecheckid->id } ) {
                $hash->{exception} = $ex->args;
            }
            else {
                $hash->{exception} = undef;
            }

            if ( my $timed = $timed_exceptions{ $rel->servicecheckid->id } ) {
                $hash->{timed_exception} = {
                    args       => $timed->args,
                    timeperiod => { name => $timed->timeperiod->name }
                };
            }
            else {
                $hash->{timed_exception} = undef;
            }

            push @{ $data->{servicechecks} }, $hash;
        }
    }

    if ( delete $serialize_columns->{hostattributes} ) {
        $data->{hostattributes} = [];
        foreach my $attr ( $self->hostattributes ) {
            my $hash = $attr->serialize_to_hash;
            push @{ $data->{hostattributes} }, $hash;
        }
    }

    if ( delete $serialize_columns->{icon} ) {
        $data->{icon} = {
            name => $self->icon->name,
            path => $self->icon->path,
        };
    }
}

sub relationships_to_related_class {
    {
        "check_period" => {
            type  => "single",
            class => "Opsview::Schema::Timeperiods",
        },
        "notification_period" => {
            type  => "single",
            class => "Opsview::Schema::Timeperiods",
        },
        "monitored_by" => {
            type  => "single",
            class => "Opsview::Schema::Monitoringservers",
        },
        "check_command" => {
            type  => "single",
            class => "Opsview::Schema::Hostcheckcommands",
        },
        "icon" => {
            type  => "single",
            class => "Opsview::Schema::Icons",
        },
        "hostgroup" => {
            type  => "single",
            class => "Opsview::Schema::Hostgroups",
        },
        "parents" => {
            type  => "multi",
            class => "Opsview::Schema::Hosts"
        },
        "hosttemplates" => {
            type  => "multi",
            class => "Opsview::Schema::Hosttemplates"
        },
        "servicechecks" => {
            type  => "multi",
            class => "Opsview::Schema::Servicechecks"
        },
        "keywords" => {
            type  => "multi",
            class => "Opsview::Schema::Keywords"
        },

        # Damnit! I think this is yet another different type than a has_many
        # This needs to be a multi so that the attribute name has a lookup
        # We then use the overrides to actually update the system
        "hostattributes" => {
            type  => "multi",
            class => "Opsview::Schema::Attributes"
        },
        "rancid_vendor" => {
            type  => "single",
            class => "Opsview::Schema::RancidVendors",
        },
    };
}

# We sort out storage so that the icon field is always populated
sub store_column {
    my ( $self, $name, $value ) = @_;
    if ( $name eq "icon" ) {
        if ( !defined $value || $value eq "" ) {
            $value = "LOGO - Opsview";
        }
    }
    $self->next::method( $name, $value );
}

sub new {
    my ( $class, $attrs ) = @_;

    unless ( $attrs->{monitored_by} ) {
        $attrs->{monitored_by} = 1;
    }

    unless ( $attrs->{ip} ) {
        $attrs->{ip} = $attrs->{name};
    }

    my $new = $class->next::method($attrs);
    return $new;
}

sub ip {
    my $self = shift;
    if (@_) {
        my $new_value = $_[0];
        if ( !defined $new_value ) {
            $new_value = $self->name;
        }
        return $self->_ip($new_value);
    }
    return $self->_ip;
}

sub list_keywords {
    my ( $self, $sep ) = @_;
    $sep ||= ",";
    return join( $sep, map { $_->name } $self->keywords );
}

# Remove these compatibility layers in future
use Opsview::Host;

sub class_dbi_host {
    my $self = shift;
    unless ( exists $self->{opsview_stash}->{class_dbi_host} ) {
        $self->{opsview_stash}->{class_dbi_host} =
          Opsview::Host->retrieve( $self->id );
    }
    return $self->{opsview_stash}->{class_dbi_host};
}

sub resolved_servicechecks {
    my ( $self, @args ) = @_;
    return $self->class_dbi_host->resolved_servicechecks(@args);
}

sub list_managementurls {
    my ( $self, @args ) = @_;
    return $self->class_dbi_host->list_managementurls(@args);
}

sub find_parents {
    my ( $self, @args ) = @_;
    return $self->class_dbi_host->find_parents(@args);
}

*weight = \&count_servicechecks; # Used for Set::Cluster
sub count_servicechecks { return shift->class_dbi_host->count_servicechecks; }

sub actual_snmpinterfaces_rs {
    shift->snmpinterfaces_rs( { interfacename => { "!=" => "" } } );
}

sub set_all_snmpinterfaces {
    my ( $self, $snmpinterfaces_array ) = @_;
    my @ids;

    foreach my $interface (@$snmpinterfaces_array) {
        my $interface_name = $interface->{name};
        my $obj =
          $self->snmpinterfaces( { interfacename => $interface_name } )->first;
        if ($obj) {
        }
        else {
            $obj = $self->add_to_snmpinterfaces(
                { interfacename => $interface_name }
            );
        }
        $obj->throughput_warning(
            defined $interface->{throughput_warning}
            ? $interface->{throughput_warning}
            : ""
        );
        $obj->throughput_critical(
            defined $interface->{throughput_critical}
            ? $interface->{throughput_critical}
            : ""
        );
        $obj->errors_warning(
            defined $interface->{errors_warning}
            ? $interface->{errors_warning}
            : ""
        );
        $obj->errors_critical(
            defined $interface->{errors_critical}
            ? $interface->{errors_critical}
            : ""
        );
        $obj->discards_warning(
            defined $interface->{discards_warning}
            ? $interface->{discards_warning}
            : ""
        );
        $obj->discards_critical(
            defined $interface->{discards_critical}
            ? $interface->{discards_critical}
            : ""
        );
        $obj->indexid( $interface->{indexid} || 0 );
        $obj->active( $interface->{active}   || 0 );
        $obj->update;
        push @ids, $obj->id;
    }

    # delete any interface not provided in the list
    $self->snmpinterfaces( { id => { "-not_in" => \@ids } } )->delete_all;
}

# This gets a list of the host's hostattributes for use in substitution
# if desired in the servicecheck.args
# We only cache when required (eg, from nagconfgen) because the web UI will
# need this to dynamically change
sub get_host_attributes {
    my $self = shift;
    if ($CACHE_HOST_ATTRIBUTES) {
        if ( $self->id != $cache_host_attributes_last_id ) {
            $cache_host_attributes_last_attributes =
              $self->_get_host_attributes;
        }
        return $cache_host_attributes_last_attributes;
    }
    return $self->_get_host_attributes;
}

sub _get_host_attributes {
    my $self    = shift;
    my $lookups = {};

    # Only need first host attribute of each value
    foreach my $hvar (
        $self->hostattributes(
            {},
            {
                join     => "attribute",
                prefetch => "attribute",
                group_by => [qw(attribute.name me.value)]
            }
        )
      )
    {
        my $arg_lookup_hash = $hvar->arg_lookup_hash();
        $lookups = { %$arg_lookup_hash, %$lookups };
    }
    return $lookups;
}

# Takes the commandline and substitutes host attributes with the appropriate value
# Rules are:
#  if listed in overrides, use that
#  otherwise, get list of variables for host and substitute. These vars based on value, NOT args!
#  if host has multiple variables, use first
#  if missing, replace with default value from attribute, otherwise blank
sub substitute_host_attributes {
    my ( $self, $commandline, $overrides ) = @_;

    # Copy overrides
    my $lookups = { %{ $overrides || {} } };

    # Capture the whole host attribute and split into components
    my $hostvar_regexp = Opsview::Config->parse_attributes_regexp;
    my ( $key, $attribute_name, $argX );

    # There's a caching that is occuring with the lookups hash
    # If the command line contains an attribute that is not in the lookups table, we look for
    # the value and also work out all the other host attribute values too, to save a later lookup
    while ( ( $key, $attribute_name, undef, $argX ) =
        ( $commandline =~ $hostvar_regexp ) )
    {

        my $newval = "";
        if ( not exists $lookups->{$key} ) {

            # Load values from each host attribute
            my $host_attributes = $self->get_host_attributes();
            $lookups = { %$host_attributes, %$lookups };

            if ( not exists $lookups->{$key} ) {

                # Find default value for this attribute
                if ( my $attribute =
                    $self->result_source->schema->resultset("Attributes")
                    ->find( { name => $attribute_name } ) )
                {

                    if ($argX) {
                        $_      = "arg$argX";
                        $newval = $attribute->$_;
                    }
                    else {
                        $newval = $attribute->value;
                    }

                }
                else {

                    # If it doesnt exist, put the attribute name back in to the
                    # the command as it might be a date format specifier or
                    # similar that should be passed on

                    # NOTE: don't use % here but something unique that will be
                    # changed later, else get into loop from the above while()
                    $lookups->{$key} = chr(0x1A) . ${key} . chr(0x1A);
                }
            }
        }
        if ( exists $lookups->{$key} ) {
            $newval = $lookups->{$key};
        }
        $commandline =~ s/%$key%/$newval/g;
    }

    # look for and swap out markers from reinstated attributes
    $commandline =~ s/\x1A/%/g;

    $commandline;
}

# WARNING!!!! A lot of duplicated code here with host_attributes_for_name()
# I think this belongs in Opsview::Schema::Attributes, so refactoring required later

# This is used for converting an argument into a command line
# taking into account multiple services
# It does a lookup to work out the override parameters and then calls substitute_host_attributes()
# Expects input of:
#   { commandline => "string with %DISK% and %DISK:1%", attribute => "DISK", value => "/var" }
sub substitute_host_attributes_with_possible_attribute {
    my ( $self, $args ) = @_;
    die "Needs commandline" unless $args->{commandline};
    my $overrides = {};
    if ( my $attr = $args->{attribute} ) {

        my $host_attribute;
        if (0) {
        }
        elsif ( $attr->name eq "SLAVENODE" ) {
            if ( $self->result_source->schema->resultset("Monitoringservers")
                ->find(1)->host->id == $self->id )
            {
                my $found_node;
                foreach my $slave (
                    $self->result_source->schema->resultset(
                        "Monitoringservers")->search_slaves
                  )
                {
                    next unless $slave->is_active;
                    my @nodes = $slave->nodes;
                    foreach my $node (@nodes) {
                        if ( $node->host->name eq $args->{value} ) {
                            $found_node = $node;
                            last;
                        }
                    }
                    if ($found_node) {
                        $host_attribute = $self->hostattributes->new(
                            {
                                attribute => $attr,
                                value     => $found_node->host->name,
                            }
                        );
                    }
                }
            }
        }
        elsif ( $attr->name eq "CLUSTERNODE" ) {

            # This macro is assigned to every host that is used as a cluster node. It returns a list of other cluster nodes in the
            # same slave system
            if (
                my $this_node = $self->result_source->schema->resultset(
                    "Monitoringclusternodes")->find( { host => $self->id } )
              )
            {
                my @other_nodes = $self->result_source->schema->resultset(
                    "Monitoringclusternodes")->search(
                    {
                        monitoringcluster => $this_node->monitoringcluster,
                        id                => { "!=" => $this_node->id },
                    }
                    );
                my $found_node;
                foreach my $other_node (@other_nodes) {
                    if ( $other_node->host->name eq $args->{value} ) {
                        $found_node = $other_node;
                        last;
                    }
                }
                if ($found_node) {
                    $host_attribute = $self->hostattributes->new(
                        {
                            attribute => $attr,
                            value     => $found_node->host->name,
                            arg1      => $found_node->host->ip,
                        }
                    );
                }
            }
        }
        elsif ( $attr->name eq "INTERFACE" ) {

            if ( $self->enable_snmp ) {

                my $default_thresholds =
                  $self->snmpinterfaces( { interfacename => "" } )->first;
                my $threshold_args = sub {
                    my ( $int, $field ) = @_;
                    my @commandargs = ();
                    foreach my $level (
                        {
                            suffix => "warning",
                            param  => "-w"
                        },
                        {
                            suffix => "critical",
                            param  => "-c"
                        }
                      )
                    {
                        my $method = "${field}_" . $level->{suffix};
                        my $value  = $int->$method;

                        # Inherit from default if appropriate
                        if ( defined $value && $value eq "" ) {
                            $value = $default_thresholds->$method
                              if $default_thresholds;
                        }

                        # Check $value ne "" because if default threshold has "" (which it shouldn't), then will get plugin syntax error
                        if ( defined $value && $value ne "" ) {
                            push @commandargs, $level->{param}, $value;
                        }
                    }
                    return join( " ", @commandargs );
                };

                # List snmpinterfaces and construct the arguments - empty lists will be ignored appropriately
                my $snmpinterface = $self->snmpinterfaces(
                    {
                        active             => 1,
                        shortinterfacename => $args->{value}
                    }
                )->first;
                my $throughput_thresholds =
                  $threshold_args->( $snmpinterface, "throughput" );
                my $errors_thresholds =
                  $threshold_args->( $snmpinterface, "errors" );
                my $discards_thresholds =
                  $threshold_args->( $snmpinterface, "discards" );

                my $snmp_auth;
                if ( $self->snmp_version eq "3" ) {
                    my $snmpv3_username = Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_username
                        )
                    );
                    my $snmpv3_authprotocol =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_authprotocol
                        )
                      );
                    my $snmpv3_authpassword =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_authpassword
                        )
                      );
                    my $snmpv3_privprotocol =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_privprotocol
                        )
                      );
                    my $snmpv3_privpassword =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_privpassword
                        )
                      );
                    $snmp_auth =
                      "-v 3 -u $snmpv3_username -a $snmpv3_authprotocol -A $snmpv3_authpassword -x $snmpv3_privprotocol -X $snmpv3_privpassword";
                }
                else {
                    $snmp_auth =
                        "-v "
                      . $self->snmp_version . " -C "
                      . (
                        Opsview::Utils->make_shell_friendly(
                            Opsview::Utils->cleanup_args_for_nagios(
                                $self->snmp_community
                            )
                        )
                      );
                }

                # snmp port
                $snmp_auth .= " -p " . $self->snmp_port;

                if ( $self->tidy_ifdescr_level ) {
                    $snmp_auth .= ' -l ' . $self->tidy_ifdescr_level;
                }
                if ( $self->snmp_max_msg_size ) {
                    $snmp_auth .= ' -m ' . $self->snmp_max_msg_size;
                }
                my ( $interfacename, $index ) =
                  $snmpinterface->actual_interface_name_and_index;
                my $what =
                  Opsview::Utils->make_shell_friendly(
                    Opsview::Utils->cleanup_args_for_nagios($interfacename)
                  );
                $what .= " -n $index" if $index;
                $host_attribute = $self->hostattributes->new(
                    {
                        attribute => $attr,
                        value     => $snmpinterface->shortinterfacename,
                        arg1      => "$snmp_auth -I $what",
                        arg2      => $throughput_thresholds,
                        arg3      => $errors_thresholds,
                        arg4      => $discards_thresholds,
                    }
                );
            }
        }
        else {
            my $host_attribute_rs = $self->hostattributes(
                {
                    attribute  => $args->{attribute}->id,
                    "me.value" => $args->{value}
                }
            );
            if ( $host_attribute_rs->count > 1 ) {
                die "Found more than 1 host attribute - not right";
            }
            $host_attribute = $host_attribute_rs->first;
        }
        if ($host_attribute) {
            $overrides = $host_attribute->arg_lookup_hash();
        }
    }
    return $self->substitute_host_attributes( $args->{commandline},
        $overrides );
}

# Cache: speeds up lookup
my $interface_attributes_cached;

# Use this at nagconfgen because you may want to read in dynamic host attributes
sub host_attributes_for_name {
    my ( $self, $host_attr_name, $exclude_clustered_slaves ) = @_;
    my @results;
    if ( $host_attr_name eq "SLAVENODE" ) {

        # This macro is only assigned to the host which is the master monitoring server
        if ( $self->result_source->schema->resultset("Monitoringservers")
            ->find(1)->host->id == $self->id )
        {
            my $slavenode =
              $self->result_source->schema->resultset("Attributes")
              ->find( { name => "SLAVENODE" } );
            foreach my $slave (
                $self->result_source->schema->resultset("Monitoringservers")
                ->search_slaves )
            {
                next unless $slave->is_active;
                my @nodes = $slave->nodes;
                next if $exclude_clustered_slaves && @nodes > 1;
                foreach my $node (@nodes) {

                    # Magic! We create a result that looks like it came from the DB!
                    my $hostattribute = $self->hostattributes->new(
                        {
                            attribute => $slavenode,
                            value     => $node->host->name,
                        }
                    );
                    push @results, $hostattribute;
                }
            }
        }
    }
    elsif ( $host_attr_name eq "CLUSTERNODE" ) {

        # This macro is assigned to every host that is used as a cluster node. It returns a list of other cluster nodes in the
        # same slave system
        if ( my $this_node =
            $self->result_source->schema->resultset("Monitoringclusternodes")
            ->find( { host => $self->id } ) )
        {
            my $clusternode_attribute =
              $self->result_source->schema->resultset("Attributes")
              ->find( { name => "CLUSTERNODE" } );
            my @other_nodes =
              $self->result_source->schema->resultset("Monitoringclusternodes")
              ->search(
                {
                    monitoringcluster => $this_node->monitoringcluster,
                    id                => { "!=" => $this_node->id },
                }
              );
            foreach my $other_node (@other_nodes) {
                my $hostattribute = $self->hostattributes->new(
                    {
                        attribute => $clusternode_attribute,
                        value     => $other_node->host->name,
                        arg1      => $other_node->host->ip,
                    }
                );
                push @results, $hostattribute;
            }
        }
    }
    elsif ( $host_attr_name eq "INTERFACE" ) {

        if ( $self->enable_snmp ) {

            my $interface_attributes = $interface_attributes_cached
              || ( $interface_attributes_cached =
                $self->result_source->schema->resultset("Attributes")
                ->find( { name => "INTERFACE" } ) );

            my $default_thresholds =
              $self->snmpinterfaces( { interfacename => "" } )->first;
            my $threshold_args = sub {
                my ( $int, $field ) = @_;
                my @commandargs = ();
                foreach my $level (
                    {
                        suffix => "warning",
                        param  => "-w"
                    },
                    {
                        suffix => "critical",
                        param  => "-c"
                    }
                  )
                {
                    my $method = "${field}_" . $level->{suffix};
                    my $value  = $int->$method;

                    # Inherit from default if appropriate
                    if ( defined $value && $value eq "" ) {
                        $value = $default_thresholds->$method
                          if $default_thresholds;
                    }

                    # Check $value ne "" because if default threshold has "" (which it shouldn't), then will get plugin syntax error
                    if ( defined $value && $value ne "" ) {
                        push @commandargs, $level->{param}, $value;
                    }
                }
                return join( " ", @commandargs );
            };

            # List snmpinterfaces and construct the arguments - empty lists will be ignored appropriately
            my @snmpinterfaces = $self->snmpinterfaces( { active => 1 } );
            foreach my $snmpinterface (@snmpinterfaces) {
                my $throughput_thresholds =
                  $threshold_args->( $snmpinterface, "throughput" );
                my $errors_thresholds =
                  $threshold_args->( $snmpinterface, "errors" );
                my $discards_thresholds =
                  $threshold_args->( $snmpinterface, "discards" );

                my $snmp_auth;
                if ( $self->snmp_version eq "3" ) {
                    my $snmpv3_username = Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_username
                        )
                    );
                    my $snmpv3_authprotocol =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_authprotocol
                        )
                      );
                    my $snmpv3_authpassword =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_authpassword
                        )
                      );
                    my $snmpv3_privprotocol =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_privprotocol
                        )
                      );
                    my $snmpv3_privpassword =
                      Opsview::Utils->make_shell_friendly(
                        Opsview::Utils->cleanup_args_for_nagios(
                            $self->snmpv3_privpassword
                        )
                      );
                    $snmp_auth =
                      "-v 3 -u $snmpv3_username -a $snmpv3_authprotocol -A $snmpv3_authpassword -x $snmpv3_privprotocol -X $snmpv3_privpassword";
                }
                else {
                    $snmp_auth =
                        "-v "
                      . $self->snmp_version . " -C "
                      . (
                        Opsview::Utils->make_shell_friendly(
                            Opsview::Utils->cleanup_args_for_nagios(
                                $self->snmp_community
                            )
                        )
                      );
                }

                # snmp port
                $snmp_auth .= " -p " . $self->snmp_port;

                if ( $self->tidy_ifdescr_level ) {
                    $snmp_auth .= ' -l ' . $self->tidy_ifdescr_level;
                }
                if ( $self->snmp_max_msg_size ) {
                    $snmp_auth .= ' -m ' . $self->snmp_max_msg_size;
                }
                my ( $interfacename, $index ) =
                  $snmpinterface->actual_interface_name_and_index;
                my $what =
                  Opsview::Utils->make_shell_friendly(
                    Opsview::Utils->cleanup_args_for_nagios($interfacename)
                  );
                $what .= " -n $index" if $index;
                my $hostattribute = $self->hostattributes->new(
                    {
                        attribute => $interface_attributes,
                        value     => $snmpinterface->shortinterfacename,
                        arg1      => "$snmp_auth -I $what",
                        arg2      => $throughput_thresholds,
                        arg3      => $errors_thresholds,
                        arg4      => $discards_thresholds,
                    }
                );
                push @results, $hostattribute;
            }
        }
    }
    else {
        @results = $self->hostattributes(
            { "attribute.name" => $host_attr_name },
            {
                prefetch => "attribute",
                join     => "attribute",
            }
        );
    }
    return @results;
}

# Returns an arrayref of errors
sub set_downtime {
    my ( $self, $contact_obj, $config ) = @_;

    my $author = "";
    if ( ref $contact_obj ) {
        if ( my $method = $contact_obj->can('name') ) {
            $author = $method->($contact_obj);
        }
    }
    my $audit_log_message;
    my $start = $config->{start_timev};
    my $end   = $config->{end_timev};
    my @errors;
    try {
        my $comment = "Host '" . $self->name . "': " . $config->{comment};
        my $cmd     = Opsview::Externalcommand->new(
            command => "SCHEDULE_HOST_SVC_DOWNTIME",
            args    => $self->name . ";$start;$end;1;0;;$author;$comment",
        );
        $cmd->submit;
        $cmd = Opsview::Externalcommand->new(
            command => "SCHEDULE_HOST_DOWNTIME",
            args    => $self->name . ";$start;$end;1;0;;$author;$comment",
        );
        $cmd->submit;

        $audit_log_message =
            "Downtime scheduled for host id "
          . $self->id . " ('"
          . $self->name
          . "'): starting "
          . scalar localtime($start)
          . ", ending "
          . scalar localtime($end) . ": "
          . $config->{comment};
    }
    catch {
        $audit_log_message =
          "Failure scheduling downtime for host '" . $self->name . "': $_";
        push @errors, $audit_log_message;
    };
    Opsview::Auditlog->create(
        {
            username => $author,
            text     => $audit_log_message,
        }
    );

    return \@errors;
}

# Validation information using DBIx::Class::Validation
__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

# icon should be a required field, but this is not enforced at the moment. There are
# various tests failures if this happens
# store_column() will default to the LOGO - Opsview, so an icon will always get set
sub get_dfv_profile {
    return {
        required => [qw/name/],
        optional => [
            qw/ip snmpv3_authpassword snmpv3_privpassword other_addresses
              rancid_password notification_options snmp_version nmis_node_type
              event_handler/
        ],
        constraint_methods => {
            name => qr/^[\w\.-]{1,63}$/,

            # The ?: is required because of D::FV which will return a fail because the first cluster back is
            # '', which it considers as a fail
            # Using ?: could have problems for javascript front end use of this, but we'll cross that when we come to it
            other_addresses      => qr/^ *(?:(?:[\w\.:-]+)?(?: *, *)?)* *$/,
            snmpv3_authpassword  => qr/^$|^.{8,}$/,
            snmpv3_privpassword  => qr/^$|^.{8,}$/,
            rancid_password      => qr/^[^{}]*$/,
            notification_options => qr/^([udrfsn])(,[udrfs])*$/,
            snmp_version         => qr/^(1|2c|3)$/,
            nmis_node_type       => qr/^(router|switch|server)$/,
            event_handler        => qr/^(?:[\w\.\$ -]+)?$/,

            # This perhaps should be a white list rather than a black list
            ip => qr/^[^\[\]`~!\$%^&*|'"<>?,()= ]{1,254}$/,
        },
        msgs => { format => "%s", },
    };
}

=item $self->hostip( $address )

Uses $address if specified, otherwise $self->ip.

Returns an array ref of ip addresses for this host, as resolved by gethostbyname(3).  Returns
an empty array ref if unable to resolve it correctly.

=cut

sub hostip {
    my ( $self, $address ) = @_;
    use Net::hostent;
    use Socket;
    $address = $self->ip unless defined $address;

    if ( $address =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
        return [$address];
    }

    $_ = Net::hostent::gethost($address);
    unless ($_) {
        return [];
    }
    my @addresses = ();
    for my $addr ( @{ $_->addr_list } ) {
        push @addresses, inet_ntoa($addr);
    }
    return \@addresses;
}

1;
