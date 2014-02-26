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
package Opsview::Wiki;

use strict;
use warnings;

use Text::WikiFormat;

# This package is for utility functions that do not
# require the database

=item Opsview::Wiki->convert_to_html( $wiki_text )

Converts $wiki_text into html

=cut

sub convert_to_html {
    my ( $self, $raw ) = @_;

    # Some javascript libraries can interferre with encoding so ensure the
    # necessary fixes are applied before any conversions are done
    $raw =~ s/&apos;/\'/gxms;

    return Text::WikiFormat::format(
        $raw,
        {},
        {
            extended       => 1,
            implicit_links => 0,
            absolute_links => 1,
        }
    );
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
