use utf8;

package Runtime::Schema::OpsviewMonitoringserver;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Runtime::Schema::OpsviewMonitoringserver - Runtime list of monitoring servers

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<opsview_monitoringservers>

=cut

__PACKAGE__->table( "opsview_monitoringservers" );

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 activated

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 passive

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 nodes

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "id",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "name",
    {
        data_type     => "varchar",
        default_value => "",
        is_nullable   => 0,
        size          => 64
    },
    "activated",
    {
        data_type     => "tinyint",
        default_value => 1,
        is_nullable   => 0
    },
    "passive",
    {
        data_type     => "tinyint",
        default_value => 0,
        is_nullable   => 0
    },
    "nodes",
    {
        data_type   => "text",
        is_nullable => 0
    },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->has_many(
    "hosts",
    "Runtime::Schema::OpsviewHosts",
    { "foreign.monitored_by" => "self.id" },
    { join_type              => "inner" }
);

# Created by DBIx::Class::Schema::Loader v0.07025 @ 2012-08-13 14:19:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1LsKpwiNe3Ap/MJCM0i9BA

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
