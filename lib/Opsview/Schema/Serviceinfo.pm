package Opsview::Schema::Serviceinfo;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common", "Core" );

=head1 NAME

Opsview::Schema::Serviceinfo

=cut

__PACKAGE__->table( __PACKAGE__->opsviewdb . ".serviceinfo" );

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

=head2 information

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
    "id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "information",
    {
        data_type   => "text",
        is_nullable => 1
    },
);
__PACKAGE__->set_primary_key( "id" );

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-09-21 10:10:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4LwLgZP51l3HeP7NX4aVxw

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
