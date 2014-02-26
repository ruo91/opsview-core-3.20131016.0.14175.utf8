#
# AUTHORS:
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
package Opsview::DBIx::Class::Common;

use strict;
use warnings;

use base qw/DBIx::Class/;

sub store_column {
    my ( $self, $name, $value ) = @_;
    if ( my $constraint =
        $self->result_source->column_info($name)->{constrain_regex} )
    {
        my $regex = $constraint->{regex};
        if ( $value !~ /$regex/ ) {
            $self->throw_exception(
                "Failed constraint on $name for '$value' with regex '$regex'"
            );
        }
    }
    if ( $name eq "uncommitted" && $value ) {
        $self->result_source->schema->resultset("Metadata")->find("uncommitted")
          ->update( { value => 1 } );
    }
    $self->next::method( $name, $value );
}

sub delete {
    my ( $self, @args ) = @_;
    $self->result_source->schema->resultset("Metadata")->find("uncommitted")
      ->update( { value => 1 } );
    $self->next::method(@args);
}

1;
