#!/usr/bin/perl
#

################################################################
# query_host.cgi
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
################################################################

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use Opsview;
use Opsview::Monitoringserver;

$| = 1; # Set autoflush on stdout

my $q = CGI->new;

print $q->header( "text/html" ); # Required for CGI

my $host           = $q->param("host") or die "No hostname specified";
my $snmp_community = $q->param( "snmp_community" );
my $msid           = $q->param( "msid" );
my $cmd            = "$Bin/../bin/query_host -w -H $host -C '$snmp_community'";

if ($msid) {
    my $ms = Opsview::Monitoringserver->retrieve($msid);
    if ( $ms->is_slave ) {
        $cmd = "$cmd -M " . $ms->host->ip;
    }
}

my $output = `$cmd`;
print $output;
