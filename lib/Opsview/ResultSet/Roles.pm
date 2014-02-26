#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

package Opsview::ResultSet::Roles;

use strict;
use warnings;
use Opsview::Utils;

use base qw/Opsview::ResultSet/;

sub synchronise_override_contacts {
    my ( $self, $object, $contacts, $errors ) = @_;

    # Synchronise contacts. Could fail if the current role has more contacts than listed here
    # This is because we don't know what role to put a contact that has been taken out into instead
    #if ( my $contacts = $attrs->{contacts} ) {
    my %current_related_ids =
      map { ( $_->id => 1 ) } ( $object->search_related("contacts") );
    $contacts = convert_to_arrayref($contacts);
    foreach my $contact (@$contacts) {
        $contact->update_from_related( "role", $object );
        delete $current_related_ids{ $contact->id };
    }
    my $to_delete = [ keys %current_related_ids ];
    if (@$to_delete) {
        my @names =
          map { $_->name }
          ( $object->search_related( "contacts", { id => $to_delete } ) );
        die
          "There are some contacts which do not have any roles after this operation: "
          . join( ", ", @names ) . "\n";
    }

    #}
}

sub synchronise_intxn_post {
    my ( $self, $object, $attrs ) = @_;

    $object->remove_objects_from_notificationprofiles;
}

# This orders the roles based on system ones which cannot be deleted first
sub search_ordered_roles {
    return shift->search(
        {},
        {
            "+select" => [
                \"
            IF( me.id < 10,
                    me.id,
                    10000
            ) AS sysid
        "
            ],
            order_by => [qw(sysid me.priority name)],
        }
    );
}

sub search_non_system_roles {
    return shift->search( { "me.id" => { ">=" => 10 } } );
}

sub actual_roles_arrayref {
    my $self    = shift;
    my @objects = $self->search_ordered_roles->search_non_system_roles;
    \@objects;
}

sub public_role           { shift->find(1) }
sub authenticated_role_id {2}
sub authenticated_role    { shift->find( __PACKAGE__->authenticated_role_id ) }

sub my_type_is {"role"}

sub restrict_by_user {
    my ( $self, $user ) = @_;
    return $self;
}

1;
