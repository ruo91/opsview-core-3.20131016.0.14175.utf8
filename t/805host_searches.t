#!/usr/bin/perl

use Test::More;
use Test::Deep;

plan 'no_plan';

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Runtime;
use Runtime::Searches;
use Runtime::Hostgroup;
use Opsview;
use Opsview::Schema;
use Runtime::Schema;
use Opsview::Test;
use Opsview::Utils;
use Clone qw(clone);

use Test::Perldump::File;

my $dbh = Runtime->db_Main;

my $schema  = Opsview::Schema->my_connect;
my $runtime = Runtime::Schema->my_connect;

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
    list => [
        {
            comments => 1,
            downtime => 0,
            flapping => 1,
            icon     => "cisco",
            name     => "cisco",
            alias    => "cisco",
            summary  => {
                handled   => 0,
                total     => 3,
                unhandled => 3,
                unknown   => { unhandled => 3 }
            },
            state      => "up",
            state_type => "soft",
            unhandled  => 0,
        },
        {
            comments => 1,
            downtime => 0,
            flapping => 1,
            icon     => "cisco",
            name     => "cisco1",
            alias    => "cisco1",
            summary  => {
                handled   => 0,
                total     => 3,
                unhandled => 3,
                unknown   => { unhandled => 3 }
            },
            state      => "up",
            state_type => "soft",
            unhandled  => 0,
        },
        {
            downtime => 2,
            flapping => 1,
            icon     => "cisco",
            name     => "cisco2",
            alias    => "cisco2",
            summary  => {
                handled   => 0,
                total     => 3,
                unhandled => 3,
                unknown   => { unhandled => 3 }
            },
            state      => "up",
            state_type => "soft",
            unhandled  => 0,
        },
        {
            downtime => 2,
            icon     => "cisco",
            name     => "cisco3",
            alias    => "cisco3",
            summary  => {
                handled   => 0,
                total     => 3,
                unhandled => 3,
                unknown   => { unhandled => 3 }
            },
            state      => "up",
            state_type => "soft",
            unhandled  => 0,
        },
        {
            downtime => 1,
            icon     => "cisco",
            name     => "cisco4",
            alias    => "cisco4",
            summary  => {
                handled   => 1,
                total     => 3,
                unhandled => 2,
                unknown   => {
                    unhandled => 2,
                    handled   => 1
                }
            },
            state      => "up",
            state_type => "soft",
            unhandled  => 0,
        },
        {
            downtime => 2,
            icon     => "dragonflybsd",
            name     => "cloned2",
            alias    => "cloned2",
            summary  => {
                handled   => 0,
                total     => 1,
                unhandled => 1,
                unknown   => { unhandled => 1 }
            },
            state      => "up",
            state_type => "hard",
            unhandled  => 0,
        },
        {
            comments => 1,
            downtime => 0,
            icon     => "debian",
            name     => "doesnt_exist_1",
            alias    => "doesnt_exist_1",
            summary  => {
                handled   => 2,
                ok        => { handled => 1 },
                total     => 2,
                unhandled => 0,
                unknown   => { handled => 1 },
            },
            state      => "down",
            state_type => "hard",
            unhandled  => 1,
        },
        {
            acknowledged => 1,
            downtime     => 0,
            icon         => "debian",
            name         => "doesnt_exist_2",
            alias        => "doesnt_exist_2",
            summary      => {
                handled   => 1,
                total     => 1,
                unhandled => 0,
                unknown   => { handled => 1 }
            },
            state      => "down",
            state_type => "hard",
            unhandled  => 0,
        },
        {
            downtime => 1,
            flapping => 1,
            icon     => "vmware",
            name     => "monitored_by_slave",
            alias    => "Host to be monitored by slave",
            summary  => {
                critical  => { unhandled => 1 },
                handled   => 0,
                total     => 3,
                unhandled => 3,
                unknown   => { unhandled => 2 },
            },
            state      => "up",
            state_type => "soft",
            unhandled  => 0,
        },
        {
            downtime => 0,
            icon     => "opsview",
            name     => "opslave",
            alias    => "Slave",
            summary  => {
                handled   => 1,
                critical  => { unhandled => 1 },
                ok        => { handled => 1 },
                total     => 2,
                unhandled => 1
            },
            state      => "up",
            state_type => "soft",
            unhandled  => 0,
        },
        {
            alias      => "Opsview Master Server",
            comments   => 1,
            downtime   => 0,
            icon       => "opsview",
            name       => "opsview",
            state      => "up",
            state_type => "soft",
            summary    => {
                critical  => { unhandled => 1 },
                handled   => 1,
                ok        => { handled   => 1 },
                total     => 2,
                unhandled => 1,
            },
            unhandled => 0,
        },
    ],
    summary => {
        handled => 16,
        host    => {
            down      => 2,
            handled   => 10,
            total     => 11,
            unhandled => 1,
            up        => 9
        },
        service => {
            critical  => 3,
            handled   => 6,
            ok        => 3,
            total     => 26,
            unhandled => 20,
            unknown   => 20
        },
        total     => 37,
        unhandled => 21,
    },

};

$status =
  Runtime::Searches->list_hosts_summarize_services_by_hostgroup( $contact,
    $hostgroup );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
cmp_deeply( $status, noclass($expected), "Got expected data for admin contact" )
  || diag( Data::Dump::dump($status) );

$status =
  Runtime::Searches->list_hosts_summarize_services_by_hostgroup( $non_admin,
    $hostgroup );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
cmp_deeply( $status, noclass($expected),
    "Got expected data for non admin contact"
);

# This $expected used to be based on the Runtime::Searches version above, but as
# the data has changed over time, we use a different file based mechanism instead
$status =
  $runtime->resultset("OpsviewHosts")->list_summary( { hostgroupid => 1 } );
Opsview::Utils->remove_keys_from_hash( $status, ["state_duration"] );

#is_deeply( $status, $expected, "Got expected data via new DBIx host" ) || diag explain $status;
is_perldump_file(
    $status,
    "$Bin/var/perldumps-805/all_hosts",
    "Got full host status"
) || diag( Data::Dump::dump($status) );

# Test a filtered status
$status = $runtime->resultset("OpsviewHosts")->list_summary(
    {
        host_filter => "handled",
        host_state  => 1
    }
);
Opsview::Utils->remove_keys_from_hash( $status, ["state_duration"] );

#is_deeply( $status, $expected, "Got host filtering correctly" ) || diag explain $status;
is_perldump_file(
    $status,
    "$Bin/var/perldumps-805/host_filtered",
    "Got full host status"
) || diag( Data::Dump::dump($status) );
