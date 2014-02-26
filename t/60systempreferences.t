#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc", "$Bin/lib";
use Opsview;

#use Opsview::Test;
use Opsview::Systempreference;

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

$dbh->do( "TRUNCATE systempreferences" );

$dbh->do( "INSERT INTO systempreferences (id) VALUES (1)" );

# set and check default values
# set to something else and try again
$dbh->do(
    "UPDATE systempreferences SET default_statusmap_layout='3',default_statuswrl_layout='2',refresh_rate='30',log_notifications='1',log_service_retries='1',log_host_retries='1',log_event_handlers='0',log_initial_states='1',log_external_commands='1',log_passive_checks='0',daemon_dumps_core='0'"
);

$_ = Opsview::Systempreference->default_statusmap_layout();
is( $_, 3, "Checking default_statusmap_layout default" );

$_ = Opsview::Systempreference->default_statuswrl_layout();
is( $_, 2, "Checking default_statuswrl_layout default" );

$_ = Opsview::Systempreference->refresh_rate();
is( $_, 30, "Checking refresh_rate default" );

$_ = Opsview::Systempreference->log_notifications();
is( $_, 1, "Checking log_notifications default" );

$_ = Opsview::Systempreference->log_service_retries();
is( $_, 1, "Checking log_service_retries default" );

$_ = Opsview::Systempreference->log_host_retries();
is( $_, 1, "Checking log_host_retries default" );

$_ = Opsview::Systempreference->log_event_handlers();
is( $_, 0, "Checking log_event_handlers default" );

$_ = Opsview::Systempreference->log_initial_states();
is( $_, 1, "Checking log_initial_states default" );

$_ = Opsview::Systempreference->log_external_commands();
is( $_, 1, "Checking log_external_commands default" );

$_ = Opsview::Systempreference->log_passive_checks();
is( $_, 0, "Checking log_passive_checks default" );

$_ = Opsview::Systempreference->daemon_dumps_core();
is( $_, 0, "Checking daemon_dumps_core default" );

# now set to new values and test again
Opsview::Systempreference->default_statusmap_layout(2);
$_ = Opsview::Systempreference->default_statusmap_layout();
is( $_, 2, "Checking default_statusmap_layout update" );

Opsview::Systempreference->default_statuswrl_layout(0);
$_ = Opsview::Systempreference->default_statuswrl_layout();
is( $_, 0, "Checking default_statuswrl_layout update" );

Opsview::Systempreference->refresh_rate(28);
$_ = Opsview::Systempreference->refresh_rate();
is( $_, 28, "Checking refresh_rate update" );

Opsview::Systempreference->log_notifications(0);
$_ = Opsview::Systempreference->log_notifications();
is( $_, 0, "Checking log_notifications update" );

Opsview::Systempreference->log_service_retries(0);
$_ = Opsview::Systempreference->log_service_retries();
is( $_, 0, "Checking log_service_retries update" );

Opsview::Systempreference->log_host_retries(0);
$_ = Opsview::Systempreference->log_host_retries();
is( $_, 0, "Checking log_host_retries update" );

Opsview::Systempreference->log_event_handlers(1);
$_ = Opsview::Systempreference->log_event_handlers();
is( $_, 1, "Checking log_event_handlers update" );

Opsview::Systempreference->log_initial_states(0);
$_ = Opsview::Systempreference->log_initial_states();
is( $_, 0, "Checking log_initial_states update" );

Opsview::Systempreference->log_external_commands(0);
$_ = Opsview::Systempreference->log_external_commands();
is( $_, 0, "Checking log_external_commands update" );

Opsview::Systempreference->log_passive_checks(1);
$_ = Opsview::Systempreference->log_passive_checks();
is( $_, 1, "Checking log_passive_checks update" );

Opsview::Systempreference->daemon_dumps_core(1);
$_ = Opsview::Systempreference->daemon_dumps_core();
is( $_, 1, "Checking daemon_dumps_core update" );
