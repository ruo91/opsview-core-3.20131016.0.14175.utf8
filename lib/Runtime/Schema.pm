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

package Runtime::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces(
    result_namespace    => [ "+Runtime::Schema", "+Opsview::Schema", ],
    resultset_namespace => [ "+Runtime::ResultSet", ],
);

use Opsview::Config;

sub my_connect {
    my ($class) = @_;
    $class->connect(
        Opsview::Config->runtime_dbi
          . ":database="
          . Opsview::Config->runtime_db
          . ";host=localhost",
        Opsview::Config->runtime_dbuser,
        Opsview::Config->runtime_dbpasswd,
        Opsview::Config->dbic_options
    );
}

1;
