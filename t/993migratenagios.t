#!/usr/bin/perl
#
#
# Test migrations from Nagios

use warnings;
use strict;
use Test::More qw(no_plan);
use FindBin qw($Bin);
use lib "$Bin/lib";
use Opsview::Test qw(stop);
use File::Path;
use File::Copy;
use Cwd;

my $topdir = "$Bin/..";

( system("$topdir/bin/db_opsview db_install") == 0 )
  or die "db_install failure";

( system("$topdir/installer/migrate_nagios $topdir/t/var/objects.cache") == 0 )
  or die "Migrate failure";

pass( "Nagios migration passed" );
