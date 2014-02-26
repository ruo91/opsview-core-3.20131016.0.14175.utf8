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

# This package is for common contructs between Class::DBI and DBIx::Class
# versions of the model
# Common methods are added here. Aim is to remove Class::DBI over time, so
# then this file can be removed

package Opsview::Base::Icon;

use warnings;
use strict;

sub filename_jpg { my $self = shift; return $self->filename . ".jpg" }
sub filename_png { my $self = shift; return $self->filename . ".png" }
sub filename_gd2 { my $self = shift; return $self->filename . ".gd2" }

sub filename_small_png {
    my $self = shift;
    return $self->filename . "_small.png";
}

1;
