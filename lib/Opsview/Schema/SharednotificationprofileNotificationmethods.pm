package Opsview::Schema::SharednotificationprofileNotificationmethods;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );
__PACKAGE__->table(
    __PACKAGE__->opsviewdb . ".sharednotificationprofile_notificationmethods"
);
__PACKAGE__->add_columns(
    "sharednotificationprofileid",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "notificationmethodid",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
);
__PACKAGE__->set_primary_key( "sharednotificationprofileid",
    "notificationmethodid" );
__PACKAGE__->belongs_to(
    "sharednotificationprofile",
    "Opsview::Schema::Sharednotificationprofiles",
    { id => "sharednotificationprofileid" },
);
__PACKAGE__->belongs_to(
    "notificationmethod",
    "Opsview::Schema::Notificationmethods",
    { id => "notificationmethodid" },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-03-16 12:52:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WGNaKzO82jjiyPQUyxRDPg

# You can replace this text with custom content, and it will be preserved on regeneration
1;
