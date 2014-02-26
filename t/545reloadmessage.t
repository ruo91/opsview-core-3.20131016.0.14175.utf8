#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc", "$Bin/lib";
use Opsview;
use Opsview::Test qw(stop opsview);
use Opsview::Reloadmessage;
use Opsview::Monitoringserver;
use DateTime;
use Test::DatabaseRow;

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

local $Test::DatabaseRow::dbh = $dbh;

$dbh->do( "TRUNCATE reloadmessages" );

row_ok(
    sql   => "SELECT count(*) as count FROM reloadmessages",
    tests => [ count => 0 ],
    label => "No rows",
);

Opsview::Reloadmessage->create(
    {
        utime             => DateTime->now(),
        severity          => "warning",
        monitoringcluster => 1,
        message           => "testing"
    }
);

row_ok(
    table   => "reloadmessages",
    where   => [ 1 => 1 ],
    results => 1,
    tests   => [
        severity          => "warning",
        monitoringcluster => 1,
        message           => "testing"
    ],
    label => "Single row correct",
);

Opsview::Reloadmessage->create(
    {
        utime             => DateTime->now(),
        severity          => "critical",
        monitoringcluster => 1,
        message           => "Another"
    }
);

row_ok(
    table   => "reloadmessages",
    where   => [ message => "Another" ],
    results => 1,
    tests   => [
        severity          => "critical",
        monitoringcluster => 1
    ],
    label => "New critical row correct",
);

Opsview::Reloadmessage->create(
    {
        utime             => DateTime->now(),
        severity          => "warning",
        monitoringcluster => 1,
        message           => "Warning 2"
    }
);

row_ok(
    table   => "reloadmessages",
    where   => [ severity => "warning" ],
    results => 2,
    label   => "Two warnings",
);

eval {
    Opsview::Reloadmessage->create(
        {
            utime             => DateTime->now(),
            severity          => "warning",
            monitoringcluster => 456,
            message           => "No such ms"
        }
    );
};

like(
    $@,
    "/Cannot add or update a child row/",
    "Error with invalid monitoringcluster"
);

row_ok(
    sql   => "SELECT count(*) as count FROM reloadmessages",
    tests => [ count => 3 ],
    label => "Prior failure with incorrect monitoringserver",
);

my $h        = Opsview::Reloadmessage->count_messages_by_severity;
my $expected = {
    warning  => 2,
    critical => 1
};
is_deeply( $h, $expected, "Right results returned" );

Opsview::Reloadmessage->create(
    {
        utime             => DateTime->now(),
        severity          => "warning",
        monitoringcluster => 3,
        message           => "Slave 3"
    }
);

row_ok(
    table => "reloadmessages",
    where => [
        severity          => "warning",
        monitoringcluster => 3
    ],
    tests   => [ message => "Slave 3" ],
    results => 1,
    label   => "Warning for monitoringcluster 3",
);

# Test that this deletion works. Will work in Class::DBI because has_a will get called automatically, whereas
# DBIx::Class expects the DB to handle the deletion
# No harm in testing this
Opsview::Monitoringserver->retrieve(3)->delete;

row_ok(
    table => "reloadmessages",
    where => [
        severity          => "warning",
        monitoringcluster => 3
    ],
    results => 0,
    label   => "No warning for monitoringcluster 3",
);
