#!/usr/bin/perl
#
# Using test configuration files, check that the ndo.dat file size does not get too large

use warnings;
use strict;
use Test::More qw(no_plan);
use FindBin qw($Bin);
use lib "$Bin/lib";
use Opsview::Test qw(stop opsview);
use File::Path;
use File::Copy;
use Cwd;

my $topdir  = "$Bin/..";
my $rootdir = "/usr/local/nagios";
my $var     = "$rootdir/var";
my $tmp_dir = "/tmp/configs.$$";
mkdir $tmp_dir or die "Cannot create temporary directory";

diag(`ps -ef`);
unlink "$var/ndo.dat", "$var/retention.dat";
is( system("rm -f $var/spool/checkresults/*"), 0 ) or die "rm failed: $!";
diag(`ls -l $var/spool/checkresults`);
is( system("rm -f $var/ndologs/*"), 0 ) or die "rm failed: $!";
diag(`ls -l $var/ndologs`);

is(
    system("$Bin/../bin/nagconfgen.pl -t $tmp_dir"),
    0, "Created configuration"
);
system(
    "tar --exclude=.svn -cf - -C '$tmp_dir/Master Monitoring Server' . | tar -C $rootdir/etc -xf -"
  ) == 0
  or bail_out( "cp failed: $!" );
is(
    system( "$Bin/../bin/rc.opsview", "verify" ),
    0, "Verify and force configs from db"
);

note( "Running nagios for 15 seconds" );

# Set to disable other daemons
$ENV{TEST_NO_DAEMONS} = "off";
is( system( "$Bin/../bin/rc.opsview", "start" ), 0, "Started Opsview" );

sleep 15;
is( system( "$Bin/../bin/rc.opsview", "stop" ), 0, "Stopped Opsview" );
sleep 5;
opendir( NDOLOGS, "$var/ndologs" ) or die $!;
my @files = sort ( grep !/^\.\.?\z/, readdir NDOLOGS );
closedir NDOLOGS;

note( "Files found: @files" );
map { note( "Size $_=" . ( -s "$Bin/../var/ndologs/$_" ) ); } @files;

my $firstlog = shift @files;
die "No log found" unless $firstlog;

my $size = -s "$Bin/../var/ndologs/$firstlog";
note( "filesize=$size" );

# Set this value just higher than the current size,
# so we'll find out straight away if more data is being sent to NDO
my $max       = 158000;
my $variation = 5000;

my $lower_bound = $max - $variation;

# This value may change if the test db increases, or if a change in Nagios causes more data to be sent
ok( $size > $lower_bound, "Is a decent size ($size > $lower_bound)" );
ok(
    $size < $max,
    "NDO log file size $size is meant to be lower than max $max"
);

rmtree($tmp_dir) or die "Cannot remove $tmp_dir tree";
