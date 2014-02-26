#!/usr/bin/perl
#
#
# Tests audit log creation based on proxy log is correct

use warnings;
use strict;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib";
use Opsview::Auditlog;
use Test::DatabaseRow;

my $dbh = Opsview->db_Main;
local $Test::DatabaseRow::dbh = $dbh;

my @tests = (
    {
        line =>
          "[1218792220] API LOG: admin;START_OBSESSING_OVER_SVC;host_locally_monitored_v3;Interface: Ethernet0",
        user => "admin",
        text =>
          "CGI command: START_OBSESSING_OVER_SVC;host_locally_monitored_v3;Interface: Ethernet0",
        datetime => "1218792220",
    },
    {
        line =>
          "[1218792249] API LOG: tonvoon;DISABLE_SVC_NOTIFICATIONS;host_locally_monitored;Interface: Ethernet0",
        user => "tonvoon",
        text =>
          "CGI command: DISABLE_SVC_NOTIFICATIONS;host_locally_monitored;Interface: Ethernet0",
        datetime => "1218792249",
    }
);

plan tests => 1 + scalar @tests;

$dbh->do( "TRUNCATE auditlogs" );

row_ok(
    sql   => "SELECT count(*) as count FROM auditlogs",
    tests => [ count => 0 ],
    label => "No rows",
);

foreach my $t (@tests) {
    Opsview::Auditlog->insert_audit_proxy_log( $t->{line} );
    row_ok(
        sql =>
          "SELECT username, text, UNIX_TIMESTAMP(datetime) as datetime FROM auditlogs WHERE id = LAST_INSERT_ID()",
        tests => [
            username => $t->{user},
            text     => $t->{text},
            datetime => $t->{datetime}
        ],
        rows  => 1,
        label => $t->{line},
    );
}
