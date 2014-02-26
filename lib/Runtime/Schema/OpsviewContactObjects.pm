package Runtime::Schema::OpsviewContactObjects;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components( "Core" );
__PACKAGE__->table( "opsview_contact_objects" );
__PACKAGE__->add_columns(
    "contactid",
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

# Created by DBIx::Class::Schema::Loader v0.04006 @ 2009-07-29 15:15:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GF070M0zYI/N7WIUKZtMqQ

# You can replace this text with custom content, and it will be preserved on regeneration
1;
