#!/usr/bin/perl

use strict;
use RRDs;
use Test::More;
use FindBin qw($Bin);

plan tests => 11;

my $rrddir = "$Bin/var/rrd";
opendir D, $rrddir or die "Cannot open $rrddir";
my @alldumps = grep /\.dump\.gz$/, readdir D;
closedir D;

foreach my $f (@alldumps) {
    my $shortname;
    ( $shortname = $f ) =~ s/\.dump\.gz$//;
    my $newf;
    ( $newf = $f ) =~ s/\.gz$//;
    system("gunzip -cf $rrddir/$f > $rrddir/$newf") == 0 or die "Cannot gunzip";
    RRDs::restore( "$rrddir/$newf", "/usr/local/nagios/var/rrd/$shortname.rrd",
        "-f" );
    diag("Restored $newf") if ( $ENV{TEST_VERBOSE} );
    die "Error restoring $rrddir/$newf: " . RRDs::error if (RRDs::error);
}

pass( "Restored test dump files" );

# Known directory
system("rm -fr /usr/local/nagios/var/rrd/hostname") == 0
  or die "Cannot remove known directory";

system("/usr/local/nagios/installer/migrate_rrds") == 0
  or die "Cannot run migration";
ok( "Migration completed" );

ok(
    !-e "/usr/local/nagios/var/rrd/hostname",
    "migrate_rrds in test mode did not create files"
);
ok(
    -e "/usr/local/nagios/var/rrd/hostname_servicename_longdsnames.rrd",
    "And original file still exists"
);

system("rm -fr /tmp/migrate_rrds.test") == 0
  or die "Cannot remove test directory";

system("/usr/local/nagios/installer/migrate_rrds -t") == 0
  or die "Cannot run test migration";

ok(
    -e "/tmp/migrate_rrds.test/hostname/servicename/pl/value.rrd",
    "Created test rrd"
);
ok(
    -e "/usr/local/nagios/var/rrd/hostname_servicename_longdsnames.rrd",
    "And original file still exists"
);

system("/usr/local/nagios/installer/migrate_rrds -y") == 0
  or die "Cannot run actual migration";

ok(
    -e "/usr/local/nagios/var/rrd/hostname/servicename/pl/value.rrd",
    "Created actual migrated rrd"
);
ok(
    !-e "/usr/local/nagios/var/rrd/hostname_servicename_longdsnames.rrd",
    "And original file finally removed"
);

ok(
    system(
        "rrdtool dump /usr/local/nagios/var/rrd/hostname/check%20load/load1/thresholds.rrd | grep -q '<name> warning_end </name>'"
      ) == 0,
    "Got warning_end"
);
ok(
    system(
        "rrdtool dump /usr/local/nagios/var/rrd/hostname/check%20load/load1/thresholds.rrd | grep -q '<name> critical_end </name>'"
      ) == 0,
    "Got critical_end"
);
ok(
    system(
        "rrdtool dump /usr/local/nagios/var/rrd/hostname/check%20load/load1/value.rrd | grep -q '<name> value </name>'"
      ) == 0,
    "Got value"
);
