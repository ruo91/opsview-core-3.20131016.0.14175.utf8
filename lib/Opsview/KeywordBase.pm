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

# Contains common routines across all the Keyword* classes
# Expects keyword_class and keyword_col to be defined in the parent class

package Opsview::KeywordBase;
use strict;

=item set_keywords_to

Deletes the foreign key table and adds only the specified list of keywords. Duplicates are ignored

=cut

sub set_keywords_to {
    my $self = shift;
    my %seen;
    my $keyword_class =
      $self->meta_info->{has_many}->{keywords}->{foreign_class};
    my $keyword_col =
      $self->meta_info->{has_many}->{keywords}->{args}->{foreign_key};
    $keyword_class->search( $keyword_col => $self->id )->delete_all;
    foreach my $word (@_) {
        next if $seen{$word};
        $seen{$word}++;
        my $obj = Opsview::Keyword->find_or_create( { name => $word } );
        $self->add_to_keywords(
            {
                $keyword_col => $self->id,
                keywordid    => $obj->id
            }
        );
    }
}

=item list_keywords

Returns a scalar with the list of keywords, separated by $1 (default comma)

=cut

sub list_keywords {
    my ( $self, $sep ) = @_;
    $sep ||= ",";
    return join( $sep, $self->keywords );
}

1;
