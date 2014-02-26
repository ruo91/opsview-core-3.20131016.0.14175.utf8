#!/usr/bin/perl
#
# Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Opsview; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
############################
#
# This is an error handler wrapper page.
#
# NOTE: this handler may be called when an upgrade is in progress so
# better to rely on as few Opsview provided perl modules and files as possible.
# For this reason its also hard to localize

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib '/usr/local/nagios/perl/lib';
use lib '/usr/local/nagios/lib';

use CGI qw/ :standard /;

my $maintenance_file = '/usr/local/nagios/etc/maintenance';

my $cgi   = CGI->new();
my $error = $cgi->param( 'error' );
print $cgi->header();
print $cgi->start_html(
    -title => 'Opsview',
    -style => {
        -src => [
            '/stylesheets/opsview2.css', '/stylesheets/common.css',
            '/stylesheets/custom.css',
        ],
    },
);

# default to community logo
my $opsview_logo = 'OpsviewCommunityLogo-large.png';

# try to check if this is an enterprise edition but during an upgrade some
# of these methods will fail
my $yml_file = '/usr/local/opsview-web/opsview_web.yml';
if ( -s $yml_file ) {
    my $yml = read_file($yml_file);
    my ( $version, $major, $sub ) =
      $yml =~ m/^build:\s((\d+\.(\d+))\.\d+\.\d+)$/xsm;
    if ( $sub && $sub % 2 == 0 ) {
        $opsview_logo = 'OpsviewEnterpriseLogo-large.png';
    }
}

print '<div id="apache_error_page">', $/;
print '<br><br>',                     $/;
print $cgi->img(
    {
        id      => 'login_logo',
        -height => 115,
        -width  => 256,
        src     => '/images/' . $opsview_logo,
    }
);

if ( -f $maintenance_file ) {
    my $maintenance_text = read_file($maintenance_file);

    if ( !$maintenance_text ) {
        $maintenance_text = <<'MAINT';
Opsview is currently undergoing maintenance.  

Please contact the Opsview Administrators for further information.
MAINT
    }

    print $cgi->pre( { class => 'mid', }, $maintenance_text );
}
else {
    my $error_text =
        $error == 500 ? 'An internal error occurred'
      : $error == 501 ? 'Request cannot be actioned'
      : $error == 502 ? 'Opsview is not running or responding to requests'
      : $error == 503
      ? 'Opsview is not running or is not responding to requests'
      : $error == 504 ? 'Opsview did not respond in a reasonable time'
      : $error == 505 ? 'HTTP version is not supported'
      :                 'Unknown error code';

    print $cgi->start_html( 'Opsview Apache Error: ' . $error );
    print $cgi->h3( { class => 'mid', }, 'Opsview Apache Error: ', $error );
    print $cgi->p( { class => 'mid', }, $error_text );

}
print '</div>', $/;
print $cgi->end_html();

# define our own sub rather than
# - use File::Slurp as opsview-perl might be being ugpraded
# - use feature 'slurp' as might be on 5.8.4 perl
sub read_file {
    my ($file) = @_;
    my $text = '';

    open( my $fh, '<', $file );
    { local $/ = undef; $text = <$fh> };
    close($fh);

    return $text;
}
