#!/usr/bin/perl
# Test timezone values are correct, based on local timezone of server

use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Runtime::Schema;
use DateTime::Format::Strptime;

my $schema = Runtime::Schema->my_connect;

my $status = $schema->resultset("NagiosProgramstatus")->first;
is( $status->status_update_time, "2007-10-31T13:20:49" );

my $date_formatter = DateTime::Format::Strptime->new(
    pattern   => "%F %T",
    time_zone => "Europe/Paris"
);

# I would expect that DateTime::Format::Strptime would convert the existing time zone into the desired one.
# This maybe fixed in a later release
$status->status_update_time->set_formatter($date_formatter);
is( $status->status_update_time, "2007-10-31 13:20:49" );

$status->status_update_time->set_time_zone( "Europe/Paris" );
is( $status->status_update_time, "2007-10-31 14:20:49" );
