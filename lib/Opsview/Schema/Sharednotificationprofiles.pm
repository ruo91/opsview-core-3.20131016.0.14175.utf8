package Opsview::Schema::Sharednotificationprofiles;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "UTF8Columns", "Core" );

=head1 NAME

Opsview::Schema::Sharednotificationprofiles

=cut

__PACKAGE__->table( __PACKAGE__->opsviewdb . ".sharednotificationprofiles" );

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 host_notification_options

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 service_notification_options

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 notification_period

  data_type: 'integer'
  default_value: 1
  is_foreign_key: 1
  is_nullable: 0

=head2 all_hostgroups

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 all_servicegroups

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 all_keywords

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 notification_level

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 role

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 uncommitted

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 notification_level_stop

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0
    },
    "name",
    {
        data_type   => "varchar",
        is_nullable => 0,
        size        => 128
    },
    "host_notification_options",
    {
        data_type   => "varchar",
        is_nullable => 1,
        size        => 16,
        accessor    => "_host_notification_options"
    },
    "service_notification_options",
    {
        data_type   => "varchar",
        is_nullable => 1,
        size        => 16,
        accessor    => "_service_notification_options"
    },
    "notification_period",
    {
        data_type      => "integer",
        default_value  => 1,
        is_foreign_key => 1,
        is_nullable    => 0,
    },
    "all_hostgroups",
    {
        data_type     => "integer",
        default_value => 1,
        is_nullable   => 0
    },
    "all_servicegroups",
    {
        data_type     => "integer",
        default_value => 1,
        is_nullable   => 0
    },
    "all_keywords",
    {
        data_type     => "tinyint",
        default_value => 1,
        is_nullable   => 0
    },
    "notification_level",
    {
        data_type     => "integer",
        default_value => 1,
        is_nullable   => 0
    },
    "role",
    {
        data_type      => "integer",
        is_foreign_key => 1,
        is_nullable    => 0
    },
    "uncommitted",
    {
        data_type     => "integer",
        default_value => 0,
        is_nullable   => 0
    },
    "notification_level_stop",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint( "name", ["name"] );

=head1 RELATIONS

=head2 contact_sharednotificationprofiles

Type: has_many

Related object: L<Opsview::Schema::ContactSharednotificationprofiles>

=cut

__PACKAGE__->has_many(
    "contact_sharednotificationprofiles",
    "Opsview::Schema::ContactSharednotificationprofile",
    { "foreign.sharednotificationprofileid" => "self.id" },
    {
        cascade_copy   => 0,
        cascade_delete => 0
    },
);

=head2 notification_period

Type: belongs_to

Related object: L<Opsview::Schema::Timeperiod>

=cut

__PACKAGE__->belongs_to(
    "notification_period",
    "Opsview::Schema::Timeperiods",
    { id => "notification_period" },
    {
        is_deferrable => 1,
        on_delete     => "CASCADE",
        on_update     => "CASCADE"
    },
);

=head2 role

Type: belongs_to

Related object: L<Opsview::Schema::Role>

=cut

__PACKAGE__->belongs_to(
    "role",
    "Opsview::Schema::Roles",
    { id => "role" },
    {
        is_deferrable => 1,
        on_delete     => "CASCADE",
        on_update     => "CASCADE"
    },
);

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-05-18 11:05:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:idvgjhkL0AP6FXyZYm3f3A

__PACKAGE__->has_many(
    "sharednotificationprofile_hostgroups",
    "Opsview::Schema::SharednotificationprofileHostgroups",
    { "foreign.sharednotificationprofileid" => "self.id" },
);
__PACKAGE__->has_many(
    "sharednotificationprofile_keywords",
    "Opsview::Schema::SharednotificationprofileKeywords",
    { "foreign.sharednotificationprofileid" => "self.id" },
);
__PACKAGE__->has_many(
    "sharednotificationprofile_notificationmethods",
    "Opsview::Schema::SharednotificationprofileNotificationmethods",
    { "foreign.sharednotificationprofileid" => "self.id" },
);
__PACKAGE__->has_many(
    "sharednotificationprofile_servicegroups",
    "Opsview::Schema::SharednotificationprofileServicegroups",
    { "foreign.sharednotificationprofileid" => "self.id" },
);

__PACKAGE__->many_to_many( 'contacts', 'contact_sharednotificationprofiles',
    'contactid' );
__PACKAGE__->many_to_many(
    hostgroups => "sharednotificationprofile_hostgroups",
    "hostgroup"
);
__PACKAGE__->many_to_many(
    servicegroups => "sharednotificationprofile_servicegroups",
    "servicegroup"
);
__PACKAGE__->many_to_many(
    keywords => "sharednotificationprofile_keywords",
    "keyword"
);
__PACKAGE__->many_to_many(
    notificationmethods => "sharednotificationprofile_notificationmethods",
    "notificationmethod"
);

use overload
  '""'     => sub { shift->id },
  fallback => 1;

__PACKAGE__->resultset_class( "Opsview::ResultSet::Sharednotificationprofiles"
);

# Need to have id as secondary sort because notification methods listing profiles may have all at priority 1
__PACKAGE__->resultset_attributes( { order_by => ["name"] } );

sub allowed_columns {
    [
        qw(id name role
          host_notification_options service_notification_options
          notification_period notification_level notification_level_stop
          all_hostgroups all_servicegroups all_keywords
          hostgroups servicegroups keywords
          notificationmethods
          uncommitted
          )
    ];
}

sub relationships_to_related_class {
    {
        "hostgroups" => {
            type  => "multi",
            class => "Opsview::Schema::Hostgroups"
        },
        "servicegroups" => {
            type  => "multi",
            class => "Opsview::Schema::Servicegroups"
        },
        "keywords" => {
            type  => "multi",
            class => "Opsview::Schema::Keywords"
        },
        "notification_period" => {
            type  => "single",
            class => "Opsview::Schema::Timeperiods"
        },
        "notificationmethods" => {
            type  => "multi",
            class => "Opsview::Schema::Notificationmethods"
        },
        "role" => {
            type  => "single",
            class => "Opsview::Schema::Roles"
        },
    };
}

=item contactgroups

Returns the name of the contact groups this contact is authorised to view. This is
different from Opsview::Base::Contact as this needs to work out the all_hostgroups parameter first

This is called by nagconfgen, so test with 990nagconfgen.t

=cut

sub contactgroups {
    my $self = shift;
    my @cgs  = ();
    my @hgs  = $self->selected_hostgroups->search(
        {},
        {
            columns      => "id",
            result_class => "DBIx::Class::ResultClass::HashRefInflator"
        }
    );
    my @sgs = $self->selected_servicegroups->search(
        {},
        {
            columns      => "id",
            result_class => "DBIx::Class::ResultClass::HashRefInflator"
        }
    );
    foreach my $hg (@hgs) {
        foreach my $sg (@sgs) {
            push @cgs, "hostgroup" . $hg->{id} . "_servicegroup" . $sg->{id};
        }
    }
    foreach my $k (
        $self->selected_keywords->search(
            {},
            {
                columns => [ "id", "name" ],
                result_class => "DBIx::Class::ResultClass::HashRefInflator"
            }
        )
      )
    {
        push @cgs, 'k' . $k->{id} . '_' . $k->{name};
    }
    return @cgs;
}

# Returns an rs based on hostgroups this role is allowed to see
# NOTE: This is used by nagconfgen to get applicable hostgroups/servicegroups
# so changes here should be tested with 990nagconfgen.t
sub selected_hostgroups {
    my ($self) = @_;
    if ( $self->all_hostgroups ) {
        return $self->valid_hostgroups;
    }
    else {
        return $self->hostgroups;
    }
}

sub selected_servicegroups {
    my ($self) = @_;
    if ( $self->all_servicegroups ) {
        return $self->valid_servicegroups;
    }
    else {
        return $self->servicegroups;
    }
}

sub selected_keywords {
    my ($self) = @_;
    if ( $self->all_keywords ) {
        return $self->valid_keywords;
    }
    else {
        return $self->keywords;
    }
}

# valid_* is called by TT to get the list
# of applicable objects
sub valid_hostgroups {
    return shift->role->valid_hostgroups;
}

sub valid_servicegroups {
    shift->role->valid_servicegroups;
}

sub valid_keywords {
    shift->role->valid_keywords;
}

sub host_notification_options {
    my $self = shift;
    $self->notification_options( "_host_notification_options", @_ );
}

sub service_notification_options {
    my $self = shift;
    $self->notification_options( "_service_notification_options", @_ );
}

sub notification_options {
    my $self     = shift;
    my $accessor = shift;
    return $self->$accessor(@_) if @_;
    my $opts = $self->$accessor;

    return $opts if defined $opts && length $opts;
    return "n";
}

__PACKAGE__->validation_auto(1);
__PACKAGE__->validation_filter(0);
__PACKAGE__->validation_module( "Data::FormValidator" );
sub validation_profile { shift->get_dfv_profile }

sub get_dfv_profile {
    return {
        required => [qw/name/],
        optional =>
          [qw/host_notification_options service_notification_options/],
        constraint_methods => {
            name                         => qr/^[\w\. -]{1,127}$/,
            host_notification_options    => qr/^([udrfsn])(,[udrfs])*$/,
            service_notification_options => qr/^([wcurfsn])(,[wcurfs])*$/,
        },
        msgs => { format => "%s", },
    };
}

1;
