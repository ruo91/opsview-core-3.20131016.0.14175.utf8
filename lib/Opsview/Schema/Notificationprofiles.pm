package Opsview::Schema::Notificationprofiles;

use strict;
use warnings;

use base 'Opsview::DBIx::Class';

__PACKAGE__->load_components( "+Opsview::DBIx::Class::Common",
    "Validation", "UTF8Columns", "Core" );
__PACKAGE__->table( __PACKAGE__->opsviewdb . ".notificationprofiles" );
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
        data_type       => "VARCHAR",
        default_value   => undef,
        is_nullable     => 0,
        size            => 128,
        constrain_regex => { regex => '^[\w\.\@ -]+$' },
    },
    "contactid",
    {
        data_type     => "INT",
        default_value => undef,
        is_nullable   => 0,
        size          => 11
    },
    "host_notification_options",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
        accessor      => "_host_notification_options",
    },
    "service_notification_options",
    {
        data_type     => "VARCHAR",
        default_value => undef,
        is_nullable   => 1,
        size          => 16,
        accessor      => "_service_notification_options",
    },
    "notification_period",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "all_hostgroups",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "all_servicegroups",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "all_keywords",
    {
        data_type     => "TINYINT",
        default_value => 1,
        is_nullable   => 0,
        size          => 1
    },
    "notification_level",
    {
        data_type     => "INT",
        default_value => 1,
        is_nullable   => 0,
        size          => 11
    },
    "priority",
    {
        data_type     => "INT",
        default_value => 1000,
        is_nullable   => 1,
        size          => 11
    },
    "uncommitted",
    {
        data_type     => "INT",
        default_value => 0,
        is_nullable   => 0,
        size          => 11
    },
    "notification_level_stop",
    {
        data_type     => "smallint",
        default_value => 0,
        is_nullable   => 0
    },
);
__PACKAGE__->set_primary_key( "id" );
__PACKAGE__->add_unique_constraint(
    "notificationprofiles_name_contactid",
    [ "name", "contactid" ],
);
__PACKAGE__->has_many(
    "notificationprofile_hostgroups",
    "Opsview::Schema::NotificationprofileHostgroups",
    { "foreign.notificationprofileid" => "self.id" },
);
__PACKAGE__->has_many(
    "notificationprofile_keywords",
    "Opsview::Schema::NotificationprofileKeywords",
    { "foreign.notificationprofileid" => "self.id" },
);
__PACKAGE__->has_many(
    "notificationprofile_notificationmethods",
    "Opsview::Schema::NotificationprofileNotificationmethods",
    { "foreign.notificationprofileid" => "self.id" },
);
__PACKAGE__->has_many(
    "notificationprofile_servicegroups",
    "Opsview::Schema::NotificationprofileServicegroups",
    { "foreign.notificationprofileid" => "self.id" },
);
__PACKAGE__->belongs_to(
    "notification_period",
    "Opsview::Schema::Timeperiods",
    { id => "notification_period" },
);
__PACKAGE__->belongs_to( "contact", "Opsview::Schema::Contacts",
    { id => "contactid" },
);

# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-03-16 12:52:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PPLVvSD0JElXBNM0ep/f1A

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->many_to_many(
    hostgroups => "notificationprofile_hostgroups",
    "hostgroup"
);
__PACKAGE__->many_to_many(
    servicegroups => "notificationprofile_servicegroups",
    "servicegroup"
);
__PACKAGE__->many_to_many(
    keywords => "notificationprofile_keywords",
    "keyword"
);
__PACKAGE__->many_to_many(
    notificationmethods => "notificationprofile_notificationmethods",
    "notificationmethod"
);

__PACKAGE__->resultset_class( "Opsview::ResultSet::Notificationprofiles" );

# Need to have id as secondary sort because notification methods listing profiles may have all at priority 1
__PACKAGE__->resultset_attributes( { order_by => [ "priority", "id" ] } );

sub allowed_columns {
    [
        qw(id name
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
    };
}

=item contactgroups

Returns the name of the contact groups this contact is authorised to view. This is
different from Opsview::Base::Contact as this needs to work out the all_hostgroups parameter first

=cut

sub contactgroups {
    my $self = shift;
    my @cgs  = ();
    my @hgs  = $self->valid_hostgroups->search(
        {},
        {
            columns      => "id",
            result_class => "DBIx::Class::ResultClass::HashRefInflator"
        }
    );
    my @sgs = $self->valid_servicegroups->search(
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
        $self->valid_keywords->search(
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

# Returns an rs based on hostgroups this contact is allowed to see
sub valid_hostgroups {
    my ($self) = @_;
    if ( $self->all_hostgroups ) {
        return $self->contact->valid_hostgroups;
    }
    else {
        return $self->hostgroups;
    }
}

sub valid_servicegroups {
    my ($self) = @_;
    if ( $self->all_servicegroups ) {
        return $self->contact->valid_servicegroups;
    }
    else {
        return $self->servicegroups;
    }
}

sub valid_keywords {
    my ($self) = @_;
    if ( $self->all_keywords ) {
        return $self->contact->valid_keywords;
    }
    else {
        return $self->keywords;
    }
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
