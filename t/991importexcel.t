#!/usr/bin/perl
#
#
# From initial import excel sheet, import in and see if this works
# Also import a test import spreadsheet, to check validity

use warnings;
use strict;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);
use File::Path;
use File::Copy;
use Cwd;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Hosts" );

my $topdir = "$Bin/..";

plan "no_plan";

my $tmpfile = "/tmp/991importexcel.xls";
unlink $tmpfile;

is( -e $tmpfile, undef, "Output file does not exist" );

my @output =
  `$topdir/bin/import_excel -y -o $tmpfile $topdir/installer/import_excel.xls`;

my $output = join( "", @output );

like( $output, qr/Success: 2/, "Imported example two hosts" );
like( $output, qr/Failed: 0/,  "With no failures" );

is( -e $tmpfile, 1, "Output file created" );

@output =
  `$topdir/bin/import_excel -y -o $tmpfile $topdir/t/var/import_excel_test.xls`;
$output = join( "", @output );

like( $output, qr/Success: 4/, "Imported four hosts from test spreadsheet" );
like( $output, qr/Failed: 1/,  "With one expected failure" );
like(
    $output,
    qr/cisco3 failed: No related object for icon 'name=NULL'; No related object for check_period 'name=NULL'; No related object for hostgroup 'name=NULL'; No related object for monitored_by 'name=NULL'; No related object for notification_period 'name=NULL'/,
    'Got expected error'
);

my $host = $rs->find( { name => "monitored_by_slave" } );
is( $host->parents->count, 0, "parents got reset to nuffink" );
is( $host->alias,       "via spreadsheet" );
is( $host->enable_snmp, 1 );
is( $host->use_mrtg,    1 );

my @servicenames = map { $_->name } ( $host->servicechecks );
is_deeply(
    \@servicenames,
    [ "Check Loadavg", "Check Memory", "Disk", "Interface Poller", "TCP/IP" ],
    "Still got servicechecks even though spaces found"
) || diag explain \@servicenames;
@_ = $host->keywords;
is( $_[0]->name, "cisco_gp1" );
is( $_[1]->name, "cloneable" );

$host = $rs->find( { name => "cisco4" } );
is( $host->check_command, undef, "No check command set due to NULL value" );
