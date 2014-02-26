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

package Opsview::ResultSet::Contacts;

use strict;
use warnings;

use base qw/Opsview::ResultSet/;
use Opsview::Utils qw(convert_to_arrayref);

use Crypt::PasswdMD5 qw/apache_md5_crypt/;

sub synchronise_pre_txn {
    my ( $self, $attrs, $errors ) = @_;
    if ( my $raw_password = delete $attrs->{password} ) {
        $attrs->{encrypted_password} = apache_md5_crypt($raw_password);
    }
}

sub synchronise_intxn_post {
    my ( $self, $object, $attrs ) = @_;
    $self->synchronise_handle_variables( $object, $attrs );

    # Need this check because a new contact may not have role set yet
    if ( $object->role ) {
        $object->role->remove_objects_from_notificationprofiles( $object->id );

        # Remove shared notification profiles that are not applicable now
        $object->search_related("contact_sharednotificationprofiles")->search(
            {
                "sharednotificationprofileid.role" =>
                  { "!=" => $object->role->id }
            },
            { join => "sharednotificationprofileid" }
        )->delete_all;
    }
}

# Delete passwords so not stored in auditlogs
sub synchronise_amend_audit_attrs {
    my ( $self, $object, $attrs ) = @_;
    delete $attrs->{password};
    delete $attrs->{encrypted_password};
}

sub all_with_access {
    my ( $self, $access ) = @_;
    my $access_obj =
      $self->result_source->schema->resultset("Access")
      ->find( { name => $access } );
    die "cannot find $access" unless $access_obj;
    my $contacts = {};
    foreach my $r ( $access_obj->roles ) {
        foreach my $c ( $r->contacts ) {
            $contacts->{ $c->username } = $c;
        }
    }
    my @list = map { $contacts->{$_} } ( sort keys %$contacts );
    return @list;
}

sub restrict_by_user {
    my ( $self, $user ) = @_;
    return $self;
}

1;
