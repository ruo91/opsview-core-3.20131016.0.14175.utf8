#!/usr/bin/perl
#
#
# SYNTAX:
# 	populate_db.pl [initial | icons | plugins]
#
# DESCRIPTION:
# 	Populates the database based on plugins in libexec
#	If $1 = "initial", then will add in a set of default services and a
#	servicegroup called operations
#	If $1 = "icons", will regenerate icons from hosticons.db file and plugins
#	If $1 = "plugins", will only redo all the plugin helps
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

use warnings;
use strict;
use FindBin qw($Bin);
use lib "/usr/local/nagios/perl/lib";

# Need to set this as plugins expect to be available and an "su - nagios -c populate_db.pl" doesn't set
$ENV{PERL5LIB} = "/usr/local/nagios/perl/lib";

use lib "$Bin/../lib", "$Bin/../etc";
use Data::Dumper;
use Text::CSV::Simple;
use Sys::Hostname;
use Try::Tiny;
use Opsview::Utils::Plugins;

my $param = shift @ARGV || "plugins";

unless ( $param eq "initial" ) {
    my $plugins = Opsview::Utils::Plugins->new();

    my @data =
      $plugins->examine_directory_plugins( "/usr/local/nagios/libexec", );

    $plugins->populate_db( \@data );
}

populate_icons() if ( $param eq "initial" or $param eq "icons" );
populate_initial() if ( $param eq "initial" );

sub populate_icons {
    system( $Bin. '/hosticon_admin',
        'import', $Bin . '/../import/hosticons.db' ) == 0
      || die( 'Cannot import hosticons.db', $/ );
}

sub populate_initial {

    # This is a no-op as it is now handled via the import/initial_opsview.sql file
}

