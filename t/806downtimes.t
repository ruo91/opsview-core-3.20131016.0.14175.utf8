#!/usr/bin/perl

use Test::More;

use Test::Deep;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Runtime;
use Runtime::Searches;
use Runtime::Service;
use Runtime::Hostgroup;
use Runtime::Downtime;
use Opsview;
use Opsview::Test;
use Opsview::Schema;
use Runtime::Schema;

use Test::Perldump::File;

plan 'no_plan';

my $dbh = Runtime->db_Main;

my $schema = Opsview::Schema->my_connect;

my $runtime = Runtime::Schema->my_connect;
my $rs      = $runtime->resultset( "OpsviewHostObjects" );

my $contact =
  $schema->resultset("Contacts")->search( { name => "admin" } )->first;
my $non_admin =
  $schema->resultset("Contacts")->search( { name => "nonadmin" } )->first;
my $somehosts =
  $schema->resultset("Contacts")->search( { name => "somehosts" } )->first;
my $readonly =
  $schema->resultset("Contacts")->search( { name => "readonly" } )->first;

my $hostgroup = Runtime::Hostgroup->retrieve(1);

my ( $status, $expected );

$expected = {
    list    => [],
    summary => {
        handled => 0,
        host    => {
            handled   => 0,
            total     => 0,
            unhandled => 0
        },
        service => {
            handled   => 0,
            total     => 0,
            unhandled => 0
        },
        total     => 0,
        unhandled => 0,
    },
};

my $downtime = Runtime::Downtime->retrieve(1);

$status = Runtime::Searches->list_services(
    $contact,
    {
        downtime_start_time => $downtime->scheduled_start_time,
        downtime_comment    => $downtime->comment_data
    }
);

cmp_deeply( $status, noclass($expected),
    "This downtime is only for hosts, so no services will be listed"
);

$status = $rs->list_summary(
    {
        downtime_start_time => $downtime->scheduled_start_time,
        downtime_comment    => $downtime->comment_data
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_deeply( $status, $expected, "DBIx wizardry!" ) || diag explain $status;

$downtime = Runtime::Downtime->retrieve(3);

my $start_time;
$_          = $downtime->scheduled_start_time->clone->set_time_zone( "UTC" );
$start_time = $_->ymd . " " . $_->hms;
$status     = Runtime::Searches->list_services(
    $contact,
    {
        downtime_start_time => $start_time,
        downtime_comment    => $downtime->comment_data
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/downtime_multiple_services",
    "This downtime has multiple services"
);

my $dt_formatter = Opsview::Test->dt_formatter;

$status = $rs->list_summary(
    {
        downtime_start_time => $start_time,
        downtime_comment    => $downtime->comment_data
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/downtime_multiple_services",
    "DBIx wizardry!"
) || diag explain $status;

$downtime = Runtime::Downtime->retrieve(9);

$_          = $downtime->scheduled_start_time->clone->set_time_zone( "UTC" );
$start_time = $_->ymd . " " . $_->hms;
$status     = Runtime::Searches->list_services(
    $contact,
    {
        downtime_start_time => $start_time,
        downtime_comment    => $downtime->comment_data
    }
);

Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/downtime_id_9",
    "Downtime as expected for downtime id " . $downtime->id
);

$status = $rs->list_summary(
    {
        downtime_start_time => $start_time,
        downtime_comment    => $downtime->comment_data
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/downtime_id_9",
    "DBIx wizardry!"
) || diag explain $status;

$downtime = Runtime::Downtime->retrieve(11);

$_          = $downtime->scheduled_start_time->clone->set_time_zone( "UTC" );
$start_time = $_->ymd . " " . $_->hms;
$status     = Runtime::Searches->list_services(
    $contact,
    {
        downtime_start_time => $start_time,
        downtime_comment    => $downtime->comment_data
    }
);

Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/downtime_id_11",
    "Downtime as expected for downtime id " . $downtime->id
);

$status = $rs->list_summary(
    {
        downtime_start_time => $start_time,
        downtime_comment    => $downtime->comment_data
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/downtime_id_11",
    "DBIx wizardry!"
) || diag explain $status;

$downtime = Runtime::Downtime->retrieve(13);

$_          = $downtime->scheduled_start_time->clone->set_time_zone( "UTC" );
$start_time = $_->ymd . " " . $_->hms;
$status     = Runtime::Searches->list_services(
    $contact,
    {
        downtime_start_time => $start_time,
        downtime_comment    => $downtime->comment_data
    }
);

Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/downtime_id_13",
    "Downtime as expected for downtime id " . $downtime->id
);

$status = $rs->list_summary(
    {
        downtime_start_time => $start_time,
        downtime_comment    => $downtime->comment_data
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/downtime_id_13",
    "DBIx wizardry!"
) || diag explain $status;
