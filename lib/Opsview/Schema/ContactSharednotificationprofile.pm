package Opsview::Schema::ContactSharednotificationprofile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "UTF8Columns", "Core" );

=head1 NAME

Opsview::Schema::ContactSharednotificationprofile

=cut

__PACKAGE__->table(
    __PACKAGE__->opsviewdb . ".contact_sharednotificationprofile"
);

=head1 ACCESSORS

=head2 contactid

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 sharednotificationprofileid

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 priority

  data_type: 'integer'
  default_value: 1000
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "contactid",
    {
        data_type      => "integer",
        is_foreign_key => 1,
        is_nullable    => 0
    },
    "sharednotificationprofileid",
    {
        data_type      => "integer",
        is_foreign_key => 1,
        is_nullable    => 0
    },
    "priority",
    {
        data_type     => "integer",
        default_value => 1000,
        is_nullable   => 0
    },
);
__PACKAGE__->set_primary_key( "contactid", "sharednotificationprofileid" );

=head1 RELATIONS

=head2 contactid

Type: belongs_to

Related object: L<Opsview::Schema::Contact>

=cut

__PACKAGE__->belongs_to(
    "contactid",
    "Opsview::Schema::Contacts",
    { id => "contactid" },
    {
        is_deferrable => 1,
        on_delete     => "CASCADE",
        on_update     => "CASCADE"
    },
);

=head2 sharednotificationprofileid

Type: belongs_to

Related object: L<Opsview::Schema::Sharednotificationprofile>

=cut

__PACKAGE__->belongs_to(
    "sharednotificationprofileid",
    "Opsview::Schema::Sharednotificationprofiles",
    { id => "sharednotificationprofileid" },
    {
        is_deferrable => 1,
        on_delete     => "CASCADE",
        on_update     => "CASCADE"
    },
);

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-05-18 11:05:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TLhmR9SlQeDZpMgM4UoGvw

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
