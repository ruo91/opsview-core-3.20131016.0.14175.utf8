#!/usr/bin/perl
#

################################################################
# all_committed_status.cgi
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
# Prints 0 if there is an uncommitted row, else 1
################################################################

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use Opsview;
use Opsview::Host;

my $q = CGI->new;

# Expiry required for IE6 (otherwise caches cgi - how stupid!)
print $q->header(
    -type    => "text/html",
    -expires => "now"
);
if ( Opsview->all_committed ) {
    print "1";
}
else {
    print "0";
}
