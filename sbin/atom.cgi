#!/usr/bin/perl
#

################################################################
# rss.cgi
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
use CGI;
use CGI::Carp qw(fatalsToBrowser);

{ package Settings; do "/usr/local/nagios/etc/atom.cfg" }

$CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX        = 102400; # 100 Kb

my $q = CGI->new;

my $atomfile = "${Settings::atomdir}/$ENV{REMOTE_USER}.atom";
my $uuid     = $Settings::server . '/' . $ENV{REMOTE_USER};

print $q->header( -type => "application/atom+xml" );

unless ( -r $atomfile ) {
    require XML::Atom::SimpleFeed;
    my $feed = XML::Atom::SimpleFeed->new(
        id    => $uuid,
        title => $Settings::title,
        link  => $Settings::server,
        link  => {
            rel  => 'self',
            href => $Settings::server . "/atom"
        },
        author    => $Settings::author,
        generator => $Settings::software,
        icon      => $Settings::icon,
        subtitle  => "",
    );

    $feed->add_entry(
        id    => $uuid . '-1',
        title => $Settings::title,
        link  => $Settings::server,
        link  => {
            rel  => 'self',
            href => $Settings::server . "/atom"
        },
        content => "You are logged in as "
          . $ENV{REMOTE_USER}
          . ".  Either you do not have Atom feeds enabled (please speak to your Opsview administrator) or no feed information has been generated yet.",
    );

    print( $feed->as_string );

    exit;
}

open ATOM, $atomfile;
print <ATOM>;
close ATOM;
exit;
