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

package Opsview::ResultSet::Sharednotificationprofiles;

use strict;
use warnings;

use base qw/Opsview::ResultSet/;

sub my_type_is {"sharednotificationprofiles"}

sub synchronise_intxn_post {
    my ( $self, $object, $attrs ) = @_;

    # Remove all contacts that do not belong to this role
    $object->search_related("contact_sharednotificationprofiles")
      ->search( { "contactid.role" => { "!=" => $object->role->id } },
        { join => "contactid" } )->delete_all;
}

sub synchronise_intxn_many_to_many_pre {
    my ( $self, $object, $attrs ) = @_;

    # Strip all hostgroups listed that are not available from the contact
    if ( @{ $attrs->{hostgroups} || [] } ) {
        my %valid_hgs =
          map { ( $_->id => 1 ) } ( $object->role->valid_hostgroups->all );
        my @stripped =
          grep { $valid_hgs{ $_->id } } ( @{ $attrs->{hostgroups} } );
        $attrs->{hostgroups} = \@stripped;
    }
    if ( @{ $attrs->{servicegroups} || [] } ) {
        my %valid =
          map { ( $_->id => 1 ) } ( $object->role->valid_servicegroups->all );
        my @stripped =
          grep { $valid{ $_->id } } ( @{ $attrs->{servicegroups} } );
        $attrs->{servicegroups} = \@stripped;
    }
    if ( @{ $attrs->{keywords} || [] } ) {
        my %valid =
          map { ( $_->id => 1 ) } ( $object->role->valid_keywords->all );
        my @stripped = grep { $valid{ $_->id } } ( @{ $attrs->{keywords} } );
        $attrs->{keywords} = \@stripped;
    }
}

1;
