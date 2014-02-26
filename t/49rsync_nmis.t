#!/usr/bin/perl

use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../perl/lib";
use Test::More qw(no_plan);
use File::Copy;
use File::Path;
use Test::Deep;

my $rootdir = "/usr/local/nagios";

# Copy dummy NMIS config files
copy( "$Bin/var/rsync_nmis/opslaveclusterB_nodes.dat",
    "$rootdir/etc/nodes.dat" )
  or die "Can't copy nodes.dat: $!";
copy( "$Bin/var/rsync_nmis/clusterA_hosts.dat", "$rootdir/etc/hosts.dat" )
  or die "Can't copy hosts.dat: $!";

# Create dummy NMIS database files
system("rm -fr $rootdir/nmis/database") == 0 or die "rm failed: $!";
mkdir("$rootdir/nmis/database") or die "mkdir failed: $!";
system(
    "tar -cf - -C '$Bin/var/rsync_nmis/database' --exclude=.svn . | tar -C '$rootdir/nmis/database' -xf -"
  ) == 0
  or die "Can't copy dummy database: $!";

# Reset log file
my $rsync_log = "/usr/local/nagios/var/log/rsync_nmis_database.log";
open LOG, ">", $rsync_log or die "Cannot reset log file";

# Fake the rsync script
$ENV{PATH} = "$Bin/bin:$ENV{PATH}";

# Invoke rsync script
is(
    system("/usr/local/nagios/bin/rsync_nmis_database"),
    0, "rsync_nmis_database ran correctly"
);

# Read file
open LOG, $rsync_log;
my @fixed_output;
while (<LOG>) {
    chomp;
    next if /^$/;
    next if /: start/;
    next if /: end/;
    push @fixed_output, $_;
}
close LOG;

my $expected = [
    'I am node = opslaveclusterB',
    'opslave:',
    'Hosts to rsync = toclone:toclone',
    'opslaveclusterC:',
    'Hosts to rsync = monitored_by_cluster:monitored_by_clusterip',
    'Rsync for ip: 192.168.101.33',
    'Args=--bwlimit=5000 -a --files-from=- -r --stats . 192.168.101.33:/usr/local/nagios/nmis/database',
    re('rsync sub process PID is: \d+'),
    'Amending IO priority of rsync sub process to "idle"',
    'Amending CPU priority of rsync sub process to "19"',
    re('^\d+.*'),
    'health/server/toclone-reach.rrd',
    'rsync return code $?=0',
    'Rsync for ip: opslaveclusterCip',
    'Args=--bwlimit=5000 -a --files-from=- -r --stats . opslaveclusterCip:/usr/local/nagios/nmis/database',
    re('rsync sub process PID is: \d+'),
    'Amending IO priority of rsync sub process to "idle"',
    'Amending CPU priority of rsync sub process to "19"',
    re('^\d+.*'),
    'health/server/monitored_by_clusterip-reach.rrd',
    'rsync return code $?=0',
    'Removing lock file'
];

# Strip off this output. Occurs on Centos/RHEL systems, but we can ignore
@fixed_output = grep !/ioprio_set: Operation not permitted/, @fixed_output;

cmp_deeply( \@fixed_output, $expected, "Output as expected" )
  || diag explain \@fixed_output;
