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

package Opsview::ResultSet::Keywords;

use strict;
use warnings;

use base qw/Opsview::ResultSet/;

sub set_roleid {
    my ( $self, $new_roleid ) = @_;
    Opsview::Schema::Keywords->set_roleid($new_roleid);
    $self;
}

# Need to order by name in edit contacts page
sub retrieve_all { shift->search( {}, { order_by => "name" } ) }

# This removes all the keywords from notification profiles, required otherwise a
# contact could have access left over
sub synchronise_intxn_post {
    my ( $self, $object, $attrs ) = @_;

    my @valid = map { $_->id } ( $object->roles->all );
    my $rs =
      $self->result_source->schema->resultset("NotificationprofileKeywords")
      ->search(
        { "keywordid" => $object->id },
        { join        => { "notificationprofile" => { "contact" => "role" } } }
      );

    # Need to ignore roles that have all_keywords (tested in t/941keywords.t)
    my @invalid_roles = $rs->search(
        {
            "role.id"           => { -not_in => \@valid },
            "role.all_keywords" => 0
        }
    );
    $_->delete for @invalid_roles;

}

1;
