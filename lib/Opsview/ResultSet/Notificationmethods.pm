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

package Opsview::ResultSet::Notificationmethods;

use strict;
use warnings;

use base qw/Opsview::ResultSet/;

# Returns a list like:
#  ( { variable => {name}, notificationmethods => [ {notificationmethod1}, ... ] } )
# Useful to group in this way for presentation purposes
sub full_required_variables_list {
    my $self      = shift;
    my @result    = ();
    my $variables = {};
    foreach
      my $nm ( $self->search( { active => 1 }, { order_by => "priority" } ) )
    {
        foreach my $var ( split( ",", ( $nm->contact_variables || "" ) ) ) {
            if ( !exists $variables->{$var} ) {
                my $data = { variable => $var };
                $data->{notificationmethods} = $variables->{$var} =
                  [ $nm->name ];
                push @result, $data;
            }
            else {
                push @{ $variables->{$var} }, $nm->name;
            }
        }
    }
    return \@result;
}

sub synchronise_intxn_post {
    my ( $self, $object, $attrs ) = @_;
    $object->delete_related( "variables" );
    $self->synchronise_handle_variables( $object, $attrs );
}

sub my_type_is {"notificationmethods"}

1;
