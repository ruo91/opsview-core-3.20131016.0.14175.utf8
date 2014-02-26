package Runtime::Schema::OpsviewContactServices;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Runtime::Schema::OpsviewContactServices

=cut

__PACKAGE__->table( "opsview_contact_services" );

=head1 ACCESSORS

=head2 contactid

  data_type: 'integer'
  is_nullable: 0

=head2 service_object_id

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "contactid",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "service_object_id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
);

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-05-29 11:00:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Guxc1rSguO0sF/fAowguhw

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
