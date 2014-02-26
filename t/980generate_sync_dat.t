#!/usr/bin/perl
#
# From test status.dat, checks generated sync file is as expected

use warnings;
use strict;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Opsview::Test qw(stop opsview);
use File::Path;
use File::Copy;
use Cwd;

my $topdir = "$Bin/..";

plan tests => 1;

my $here    = "$Bin/var";
my $tmp_dir = "/tmp/sync.$$";
mkdir $tmp_dir or die "Cannot create temporary directory";

(
    system(
        "env TEST_NAGIOS_STATUS_DAT='$here/status.dat' $topdir/bin/generate_slave_sync_status -t $tmp_dir > /dev/null"
      ) == 0
) or die "generate_slave_sync_status failure";

my $diff = "diff -u -x .svn -r $here/syncconfigs $tmp_dir";
system( "$diff > /dev/null" );
if ( $? == 0 ) {
    pass( "Sync status matches expected" );
    rmtree($tmp_dir) or die "Cannot remove tree";
}
else {
    fail(
        "Nagios config discrepency!!!\nTest with: $diff\nCopy with: cp -r $tmp_dir/* $here/syncconfigs"
    );
}
