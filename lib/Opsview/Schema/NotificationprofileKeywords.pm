package Opsview::Schema::NotificationprofileKeywords;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".notificationprofile_keywords" );
__PACKAGE__->add_columns(
    "notificationprofileid",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "keywordid",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "notificationprofileid", "keywordid" );
__PACKAGE__->belongs_to(
    "notificationprofile",
    "Opsview::Schema::Notificationprofiles",
    { id => "notificationprofileid" },
);
__PACKAGE__->belongs_to( "keyword", "Opsview::Schema::Keywords",
    { id => "keywordid" },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-03-16 12:52:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:R9Qgp+t08E0nebqV9o0FlA

# You can replace this text with custom content, and it will be preserved on regeneration
1;
