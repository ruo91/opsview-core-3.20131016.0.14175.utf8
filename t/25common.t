#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$Bin/../lib", "t/lib";
use POSIX qw(strftime);

use_ok( "Opsview::Common" );

my ( $start_dt, $start_string, $start_epoc, $end_dt, $end_string, $end_epoc );

diag("start & end undef") if ( $ENV{TEST_VERBOSE} );
( $start_dt, $end_dt ) = parse_downtime_strings( "", "" );
is( $@,        "Start time is not defined", "\$@ set to '$@'" );
is( $start_dt, undef,                       "start is undef" );
is( $end_dt,   undef,                       "end is undef" );

diag("start date too old, end undef") if ( $ENV{TEST_VERBOSE} );
$start_string = "2000-01-01 00:00:00";
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, "" );
is( $@,        "Start time is too far behind in time", "\$@ set to '$@'" );
is( $start_dt, undef,                                  "start is undef" );
is( $end_dt,   undef,                                  "end is undef" );

$start_epoc = time;
$end_epoc   = $start_epoc - 3600;

diag("start date ok, end undef") if ( $ENV{TEST_VERBOSE} );
$start_string = strftime "%F %H:%M:%S", localtime($start_epoc);
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, "" );
is( $@,        "End time is not defined", "\$@ set to '$@'" );
is( $start_dt, undef,                     "start is undef" );
is( $end_dt,   undef,                     "end is undef" );

diag("start date ok, end date before start") if ( $ENV{TEST_VERBOSE} );
$end_string = strftime "%F %H:%M:%S", localtime($end_epoc);
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@,        "End time is before start time", "\$@ set to '$@'" );
is( $start_dt, undef,                           "start time is undef" );
is( $end_dt,   undef,                           "end time is undef" );

diag("start date ok, end date set to same") if ( $ENV{TEST_VERBOSE} );
$end_string = $start_string;
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@, "End time is the same as the start time", "\$@ set to '$@'" );
is( $start_dt, undef, "start time is undef" );
is( $end_dt,   undef, "end time is undef" );

diag("start date ok, end date ok, only 59 seconds difference")
  if ( $ENV{TEST_VERBOSE} );
$end_epoc = $start_epoc + 59;
$end_string = strftime "%F %H:%M:%S", localtime($end_epoc);
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@, "Cannot specify downtime of less than 1 minute", "\$@ set to '$@'" );
is( $start_dt, undef, "start time is undef" );
is( $end_dt,   undef, "end time is undef" );

diag("start date ok, end date ok") if ( $ENV{TEST_VERBOSE} );
$end_epoc = $start_epoc + 60;
$end_string = strftime "%F %H:%M:%S", localtime($end_epoc);
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@,               "",          "\$@ is unset" );
is( $start_dt->epoch, $start_epoc, "start time is correct" );
is( $end_dt->epoch,   $end_epoc,   "end time is correct" );

diag("start string too old, end undef") if ( $ENV{TEST_VERBOSE} );
$start_string = "last year";
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, "" );
is( $@,        "Start time is too far behind in time", "\$@ set to '$@'" );
is( $start_dt, undef,                                  "start is undef" );
is( $end_dt,   undef,                                  "end is undef" );

diag("start string ok, end undef") if ( $ENV{TEST_VERBOSE} );
$start_epoc   = time;
$end_epoc     = $start_epoc - 3600;
$start_string = "now";
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, "" );
is( $@,        "End time is not defined", "\$@ set to '$@'" );
is( $start_dt, undef,                     "start is undef" );
is( $end_dt,   undef,                     "end is undef" );

diag("start string ok, end string before start") if ( $ENV{TEST_VERBOSE} );
$start_epoc = time;
$end_epoc   = $start_epoc - 3600;
$end_string = "1 hour ago";
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@,        "End time is before start time", "\$@ set to '$@'" );
is( $start_dt, undef,                           "start time is undef" );
is( $end_dt,   undef,                           "end time is undef" );

diag("start date ok, end date set to same") if ( $ENV{TEST_VERBOSE} );
$start_epoc = time;
$end_epoc   = $start_epoc - 3600;
$end_string = $start_string;
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@, "End time is the same as the start time", "\$@ set to '$@'" );
is( $start_dt, undef, "start time is undef" );
is( $end_dt,   undef, "end time is undef" );

diag("start string ok, end string ok") if ( $ENV{TEST_VERBOSE} );
$start_string = "now";
$start_epoc   = time;
$end_string   = "in 1 hour";
$end_epoc     = $start_epoc + 3600;
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@, "", "\$@ is unset" );
cmp_ok(
    $start_dt->epoch - $start_epoc,
    '<=', 1, "start time is correct (with 1 second tolerance)"
);
cmp_ok(
    $end_dt->epoch - $end_epoc,
    '<=', 1, "end time is correct (with 1 second tolerance)"
);

# NOTE, invalid dates are picked up; invalid times are ignored
diag("invalid start date") if ( $ENV{TEST_VERBOSE} );
$start_string = "2036-11-32 15:00:00";
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, "" );
is( $@,        "End time is not defined", "\$@ set to '$@'" );
is( $start_dt, undef,                     "start is undef" );
is( $end_dt,   undef,                     "end is undef" );

# NOTE, invalid dates are picked up; invalid times are ignored
diag("invalid start time") if ( $ENV{TEST_VERBOSE} );
$start_string = "2036-11-16 26:00:00";
$end_string   = "2036-11-17 15:00:00";
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@, "", "\$@ is unset" );
like( $start_dt, qr/^2036-11-16T\d\d:\d\d:\d\d$/, "start time is correct" );
is( $end_dt, "2036-11-17T15:00:00", "end time is correct" );

diag("HH:00 from graphing is valid") if ( $ENV{TEST_VERBOSE} );
$start_string = "2036-11-16 18:00";
$end_string   = "2036-11-17 15:00";
( $start_dt, $end_dt ) = parse_downtime_strings( $start_string, $end_string );
is( $@,        "",                    "\$@ is unset" );
is( $start_dt, "2036-11-16T18:00:00", "start time is correct" );
is( $end_dt,   "2036-11-17T15:00:00", "end time is correct" );

( $start_dt, $end_dt ) = parse_downtime_strings( "2036-11-16 18:00", "+1h" );
is( $@,        "",                    "\$@ is unset" );
is( $start_dt, "2036-11-16T18:00:00", "start time is correct" );
is( $end_dt,   "2036-11-16T19:00:00", "end time is correct" );

( $start_dt, $end_dt ) =
  parse_downtime_strings( "2036-11-16 18:00", "+ 7d 90m 5s" );
is( $@,        "",                    "\$@ is unset" );
is( $start_dt, "2036-11-16T18:00:00", "start time is correct" );
is( $end_dt,   "2036-11-23T19:30:05", "end time is correct" );

( $start_dt, $end_dt ) =
  parse_downtime_strings( "2036-11-16 18:00", "+ 7d90m5s" );
is( $@,        "Jira style duration invalid", "\$@ is set correctly" );
is( $start_dt, undef,                         "start time is correct" );
is( $end_dt,   undef,                         "end time is correct" );
