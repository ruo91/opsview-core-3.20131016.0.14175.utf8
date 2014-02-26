#!/usr/bin/env perl

# From test db, check survey works

use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../perl/lib", "$Bin/lib";
use Test::More;
use Opsview::Test;
use File::Path;
use File::Copy;
use Cwd;

my $topdir = "$Bin/..";

# Not required as test DB does not include ODW importing
#is( system("$topdir/bin/db_odw db_install"), 0, "Installed ODW" );

# Duplicated code here but we need to know if the algorithm has changed
use Sys::Hostname;
use Socket;
use Digest::MD5 qw(md5_hex);
my $hostname = Sys::Hostname::hostname();
my $hosthash = md5_hex($hostname);
my $arch     = `uname -m`;
chomp $arch;

# $os is provided by the Hudson job, so we have to rely on it being correct in
# the opsview_build_os file.
my $os =
  do { local ( @ARGV, $/ ) = '/usr/local/nagios/etc/opsview_build_os'; <> };
$os =~ s/^([^\s]+).*/$1/s;

my $expected = [
    "arch=$arch",                "avg_reload=10",
    "hosthash=" . uc($hosthash), "include_major=1",
    "instance_id=1",             "num_api=0",
    "num_contacts=14",           "num_hosts=24",
    "num_keywords=9",            "num_logins=0",
    "num_services=52",           "num_slavenodes=6",
    "num_slaves=4",              "odw=0",
    "os=$os",                    "perl_version=$]",
    "remote_opsview_db=0",       "snmptraps=1",
    "uuid=TestDB",
];
my @full_output =
  map { chop; $_ } `$topdir/libexec/check_opsview_update --showstats=2`;
my @output;

foreach my $line (@full_output) {
    if ( $line =~ /^version=/ ) {
        like(
            $line,
            qr/^version=\d+\.\d+\.\d+\.\d+$/,
            "Version string is fine"
        );
    }
    elsif ( $line =~ /^master_cpus=/ ) {
        like( $line, qr/^master_cpus=\d+$/, "Cpu information is fine" );
    }
    elsif ( $line =~ /^master_loadavg15=/ ) {
        like(
            $line,
            qr/^master_loadavg15=\d+(\.\d+)?$/,
            "Load avg information is fine"
        );
    }
    elsif ( $line =~ /^master_memory=/ ) {
        like( $line, qr/^master_memory=\d+$/, "Memory information is fine" );
    }
    else {
        push @output, $line;
    }
}
is_deeply( \@output, $expected, "Survey ran as expected" )
  || diag explain \@output;

done_testing;
