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
package Utils::Weberrors;

use strict;
use warnings;

=item Utils::Weberrors->find_url_end( $arrayref )

Expects $arrayref as a list ref of error strings. Will return the url_end component

=cut

my $lookup_table = [
    {
        regexp  => qr/is marked as crashed and should be repaired/o,
        url_end => "mysql#fixing_damaged_database_tables",
    },
    {
        regexp  => qr/fails \'regexp\' constraint/,
        url_end => 'help#validation_errors',
    }
];

# These url_end's have to match with what's in docs.opsview.com
sub lookup_errors {
    my ( $class, $errorsref ) = @_;
    my $url_end = "webexception";
    LOOKUP:
    foreach my $lookup (@$lookup_table) {
        foreach my $error_text (@$errorsref) {
            if ( $error_text =~ $lookup->{regexp} ) {
                $url_end = $lookup->{url_end};
                last LOOKUP;
            }
        }
    }
    return $url_end;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
