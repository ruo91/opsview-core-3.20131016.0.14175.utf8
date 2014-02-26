#!/usr/bin/perl

use Test::More 'no_plan';

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;

my $rc;

chdir( "$Bin/.." );

$rc = system( "bin/rc.opsview stop" );
is( $rc, 0, "Nagios stopped" );

# Check that all daemons are stopped
diag("Checking for daemon processes - this can affect tests")
  if ( $ENV{TEST_VERBOSE} );
my @ps = `ps -ef`;
is( scalar( grep {m%bin/nagios%} @ps ), 0, "No nagios processes" );
is( scalar( grep {m%bin/nsca%} @ps ),   0, "No nsca processes" );
is( scalar( grep {m%bin/nrd%} @ps ),    0, "No nrd processes" );
is(
    scalar( grep {m%import_ndologsd%} @ps ),
    0, "No import_ndologsd processes"
);
is(
    scalar( grep {m%import_perfdatarrd%} @ps ),
    0, "No import_perfdatarrd processes"
);
is(
    scalar( grep {m%import_ndoconfigend%} @ps ),
    0, "No import_ndoconfigend processes"
);
is( scalar( grep {m%:\d\d opsviewd$%} @ps ), 0, "No opsviewd processes" );

# Check a db install works - skip opspacks
system( "bin/db_opsview -t -o db_install" );
is( $?, 0, "Return code from db_opsview -o db_install is okay" );

# Confirm import/initial_opsview.sql is up to date with schema changes
system( "bin/db_opsview db_export_initial > /tmp/initial_opsview.sql" );
is( $?, 0, "db_opsview db_export_initial ok" );
my $diff = "diff -u import/initial_opsview.sql /tmp/initial_opsview.sql";
system( "$diff > /dev/null" );
if ( $? == 0 ) {
    pass( "import/initial_opsview.sql as expected" );
    unlink "/tmp/initial_opsview.sql"
      or die "Cannot remove /tmp/initial_opsview.sql: $!";
}
else {
    fail(
        "Initial db config discrepency!!!\nTest with: $diff\nCopy with: cp /tmp/initial_opsview.sql $Bin/../import/initial_opsview.sql"
    );
    if ( $ENV{OPSVIEW_TEST_HUDSON} ) {
        system( "$diff" );
    }
}

# full install
system( "bin/db_opsview db_install" );
is( $?, 0, "Return code from db_opsview db_install is okay" );

$rc = system( "OPSVIEW_NOSTART=true bin/rc.opsview gen_config" );
is( $rc, 0, "Config generated okay from a fresh install" );

$rc = system("bin/rc.opsview status") >> 8;
is( $rc, 3, "Nagios stays down because of OPSVIEW_NOSTART" );

# Allow time for opsview backup to complete
sleep 10;

# Delete all databases first, simulating a new install
# get configured database named, just in case they have been changed
use_ok( 'Opsview::Test::Cfg' );
my $command = 'echo "';
for my $db (qw/ opsview runtime /) {
    $command .= 'DROP DATABASE IF EXISTS ' . Opsview::Test::Cfg->$db . '; ';
}
$command .= '" | mysql -u root';

diag( 'About to run: ', $command ) if ( $ENV{TEST_VERBOSE} );
$rc = system($command);
is( $rc, 0, 'Previous databases dropped OK' );

my $connections;
foreach my $db (qw(runtime opsview)) {
    my $rc = system( "bin/db_$db -t db_install" );
    ok( $rc == 0, "Created $db database" );

    my $Db = ucfirst($db);

    my $dbh = eval "require $Db; $Db->db_Main";
    ok( defined $dbh, "Connected to $Db" );

    $connections->{$db} = $dbh;
}

SKIP: {
    skip "Servicegroups installed by opspacks", 2;
    is(
        $connections->{"opsview"}->selectrow_array(
            "SELECT name FROM servicegroups WHERE name = 'Application - Opsview'"
        ),
        "Application - Opsview",
        "Must have servicegroup = Application - Opsview"
    );
    is(
        $connections->{"opsview"}->selectrow_array(
            "SELECT name FROM servicegroups WHERE name = 'Network - SNMP MIB-II'"
        ),
        "Network - SNMP MIB-II",
        "Must have servicegroup = Network - SNMP MIB-II"
    );
}

is(
    $connections->{"opsview"}
      ->selectrow_array("SELECT uuid FROM systempreferences"),
    "", "UUID is empty"
);

is(
    $connections->{"opsview"}->selectrow_array(
        "SELECT COUNT(*) FROM servicechecks WHERE uncommitted=1"),
    0,
    "No uncommitted servicechecks"
);
is(
    $connections->{"opsview"}->selectrow_array(
        "SELECT COUNT(*) FROM hosttemplates WHERE uncommitted=1"),
    0,
    "No uncommitted hosttemplates"
);

is(
    $connections->{"opsview"}->selectrow_array(
        "SELECT COUNT(*) FROM contacts WHERE show_welcome_page=0"),
    0,
    "Welcome page to be shown to everyone"
);

my @output = `installer/upgradedb.pl`;
my $num = grep /already up to date/, @output;
is( $num, 2,
    "Test if new installs cause an upgrade - if fails, probably db_* not updated with right version number"
) || print "Output:\n@output\n";

use_ok( "Opsview::Test" );

{
    local $/ = undef;
    my $output = `installer/upgradedb.pl`;
    unlike(
        $output,
        "/version/",
        "Some upgrade still required - if fails, probably not updated test dbs"
    );
}

# compare the schema from an initial install vs a schema from a backup restore
#
# create a nice & fresh opsview db
$rc = system( "bin/db_opsview db_install" );
ok( $rc == 0, "Created opsview database" );

# get a full schema list of a newly installed db without data
my $schema_command = 'mysqldump -u root --skip-comments --no-data opsview';
system( "$schema_command > /tmp/schema_test_install.sql" );
is( $?, 0, "db_opsview schema for install ok" );

# take a backup
system( 'bin/db_opsview db_backup > /tmp/schema_test_opsview_bk.sql' );
is( $?, 0, "db_opsview db_backup ok" );

# drop the db so a restore is 'fresh'
system( 'echo DROP DATABASE opsview | mysql -u root' );
is( $?, 0, "drop database opsview ok" );

# restore the backup
system( 'cat /tmp/schema_test_opsview_bk.sql | bin/db_opsview db_restore' );
is( $?, 0, "db_opsview db_restore ok" );

# get the restored schema
system( "$schema_command > /tmp/schema_test_restored.sql" );
is( $?, 0, "db_opsview schema for restore ok" );

# now compare the two
$diff = "diff -u /tmp/schema_test_install.sql /tmp/schema_test_restored.sql";
system( "$diff > /dev/null" );
if ( $? == 0 ) {
    pass( "/tmp/schema_test_restored.sql as expected" );
    for my $file (
        '/tmp/schema_test_restored.sql',
        '/tmp/schema_test_install.sql',
        '/tmp/schema_test_opsview_bk.sql'
      )
    {
        unlink $file or die "Cannot remove $file: $!";
    }
}
else {
    fail( "Restored db discrepency!!!\nTest with: $diff\n" );
    if ( $ENV{OPSVIEW_TEST_HUDSON} ) {
        system( "$diff" );
    }
}
