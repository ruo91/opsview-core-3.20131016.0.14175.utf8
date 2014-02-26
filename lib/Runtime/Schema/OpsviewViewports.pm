package Runtime::Schema::OpsviewViewports;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "opsview_viewports" );
__PACKAGE__->add_columns(
    "viewportid",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "keyword",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 128,
    },
    "hostname",
    {
        data_type     => "VARCHAR",
        default_value => "",
        is_nullable   => 0,
        size          => 64,
    },
    "servicename",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 128,
    },
    "host_object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "object_id",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2009-07-16 21:28:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:t3oVZ8w/yr8ItRqT3HT2og

# You can replace this text with custom content, and it will be preserved on regeneration

__PACKAGE__->belongs_to( "opsview_keyword", "Opsview::Schema::Keywords",
    { "foreign.id" => "self.viewportid" },
);

__PACKAGE__->has_many(
    "downtimes",
    "Runtime::Schema::NagiosScheduleddowntimes",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" }
);

__PACKAGE__->belongs_to(
    "servicestatus",
    "Runtime::Schema::NagiosServicestatus",
    { "foreign.service_object_id" => "self.object_id" },
    { join_type                   => "inner" }
);
__PACKAGE__->belongs_to(
    "hoststatus",
    "Runtime::Schema::NagiosHoststatus",
    { "foreign.host_object_id" => "self.host_object_id" },
);

__PACKAGE__->has_many(
    "contacts",
    "Runtime::Schema::OpsviewContactObjects",
    { "foreign.object_id" => "self.object_id" },
    { join_type           => "inner" },
);

1;
