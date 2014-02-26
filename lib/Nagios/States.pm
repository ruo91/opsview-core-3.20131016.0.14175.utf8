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

package Nagios::States;
use strict;
use warnings;
use Carp;

use vars qw( %states_by_id %states_by_name );

require Exporter;
our @ISA         = qw(Exporter);
our @EXPORT      = qw( %states_by_id %states_by_name );
our @EXPORT_OK   = qw( );
our %EXPORT_TAGS = qw( );
our $VERSION     = sprintf( "%d", q$Revision: 0.01 $ =~ /\d+/ );

%states_by_id = (
    0 => "OK",
    1 => "WARNING",
    2 => "CRITICAL",
    3 => "UNKNOWN",
);

%states_by_name = reverse(%states_by_id);

1;
