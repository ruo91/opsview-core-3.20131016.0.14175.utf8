#!/usr/bin/perl

use Test::More tests => 18;

#use Test::More qw(no_plan);
use Test::Deep;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Runtime;
use Runtime::Searches;
use Runtime::Service;
use Runtime::Hostgroup;
use Opsview;
use Opsview::Schema;

use_ok( 'Opsview::Test::Cfg' );

use Opsview::Test;

use Test::Perldump::File;

my $dbh = Runtime->db_Main;

my $schema = Opsview::Schema->my_connect;

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

$status = Runtime::Searches->list_summarized_hosts_services(
    $contact,
    {
        summarizeon => "hostgroup",
        hostgroupid => $hostgroup->id
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/full_hostgroup_status",
    "Got full status"
) || diag( Data::Dump::dump($status) );

$status = Runtime::Searches->list_summarized_hosts_services(
    $non_admin,
    {
        summarizeon => "hostgroup",
        hostgroupid => $hostgroup->id
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/full_hostgroup_status",
    "Got full status for non admin contact"
);

$status = Runtime::Searches->list_summarized_hosts_services(
    $somehosts,
    {
        summarizeon => "hostgroup",
        hostgroupid => $hostgroup->id
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/filtered_hostgroup_for_somehosts",
    "Filtered view for somehosts user"
);

$status = Runtime::Searches->list_summarized_hosts_services(
    $contact,
    {
        summarizeon => "hostgroup",
        hostgroupid => 5
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/hostgroup_leaf",
    "Leaf hostgroup okay"
);

$status = Runtime::Searches->list_summarized_hosts_services(
    $contact,
    {
        summarizeon => "keyword",
        keyword     => [qw(cisco cisco_gp1 cisco_gp2)]
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/summarised_keywords",
    "Got ordered by keyword"
);

$status = Runtime::Searches->list_summarized_hosts_services(
    $somehosts,
    {
        summarizeon => "keyword",
        keyword     => [qw(cisco cisco_gp1 cisco_gp2)]
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/summarised_keywords",
    "Filtered user should get same data for keywords"
);

$status = Runtime::Searches->list_summarized_hosts_services(
    $contact,
    {
        keyword     => [qw(cisco_gp1 cisco)],
        summarizeon => "keyword"
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/summarised_keywords_two",
    "Only show two keywords"
);

# Test for downtime
$expected = {
    3 => {
        comment  => "Hostgroup 'Monitoring Servers': testing",
        state    => 2,
        username => "admin",
    },
    6 => {
        comment =>
          "Hostgroup 'Leaf2': in the future <script>alert(\"badness\")</script>",
        state    => 1,
        username => "admin",
    },
};

# Parameters below duplicated from Runtime::Searches->list_summarized_hosts_services
my $hash = Runtime::Searches->_downtimes_hash(
    {
        key   => "hostgroup",
        where => {
            "opsview_hostgroups.parentid" => $hostgroup->id,
            "opsview_hostgroups.id"       => \
              "= opsview_hostgroup_hosts.hostgroup_id",
            "opsview_hostgroup_hosts.host_object_id" => \
              "= opsview_host_services.host_object_id",
        },
        tables => [
            qw(opsview_hostgroups opsview_hostgroup_hosts opsview_host_services)
        ],
    }
);
is_deeply( $hash, $expected, "Downtimes by hostgroup correct" )
  || diag( Data::Dump::dump($hash) );

$expected = {
    cisco => {
        comment  => "Hostgroup 'Monitoring Servers': testing",
        state    => 2,
        username => "admin",
    },
    cisco_gp1 => {
        comment  => "Service 'Coldstart': testing again",
        state    => 2,
        username => "admin",
    },
    cisco_gp2 => {
        comment  => "Hostgroup 'Monitoring Servers': testing",
        state    => 2,
        username => "admin",
    },
};
$hash = Runtime::Searches->_downtimes_hash(
    {
        key   => "keyword",
        where => {
            Opsview::Test::Cfg->opsview
              . '.keywords.id' => \"= opsview_viewports.viewportid"
        },
        tables => [
            qw(opsview_viewports ), Opsview::Test::Cfg->opsview . '.keywords',
        ],
    }
);
is_deeply( $hash, $expected, "Downtimes by keyword correct" )
  || diag( Data::Dump::dump($hash) );

$expected = {
    118 => {
        comment  => "Hostgroup 'Leaf': in the future",
        state    => 1,
        username => "admin",
    },
    120 => {
        comment  => "Hostgroup 'Monitoring Servers': testing",
        state    => 2,
        username => "admin",
    },
    136 => {
        comment =>
          "Hostgroup 'Leaf2': in the future <script>alert(\"badness\")</script>",
        state    => 1,
        username => "admin",
    },
    154 => {
        comment  => "Hostgroup 'Leaf': in the future",
        state    => 1,
        username => "admin",
    },
    155 => {
        comment  => "Service 'Coldstart': testing again",
        state    => 2,
        username => "admin",
    },
    158 => {
        comment  => "Service 'Coldstart': testing",
        state    => 2,
        username => "admin",
    },
    161 => {
        comment  => "Service 'Coldstart': testing",
        state    => 1,
        username => "admin",
    },
    193 => {
        comment =>
          "Hostgroup 'Leaf2': in the future <script>alert(\"badness\")</script>",
        state    => 1,
        username => "admin",
    },
    194 => {
        comment =>
          "Hostgroup 'Leaf2': in the future <script>alert(\"badness\")</script>",
        state    => 1,
        username => "admin",
    },
    195 => {
        comment =>
          "Hostgroup 'Leaf2': in the future <script>alert(\"badness\")</script>",
        state    => 1,
        username => "admin",
    },
    196 => {
        comment =>
          "Hostgroup 'Leaf2': in the future <script>alert(\"badness\")</script>",
        state    => 1,
        username => "admin",
    },
    3 => {
        comment  => "Hostgroup 'Monitoring Servers': testing",
        state    => 2,
        username => "admin",
    },
    5 => {
        comment =>
          "Hostgroup 'Leaf2': in the future <script>alert(\"badness\")</script>",
        state    => 1,
        username => "admin",
    },
};
$hash = Runtime::Searches->_downtimes_hash(
    {
        key    => "object",
        where  => {},
        tables => [qw(opsview_host_services)],
    }
);
is_deeply( $hash, $expected, "Downtimes by keyword correct" )
  || diag( Data::Dump::dump($hash) );

$expected = {
    cisco2             => 2,
    cisco3             => 2,
    cisco4             => 1,
    cloned2            => 2,
    monitored_by_slave => 1,
};
$hash =
  Runtime::Searches->downtimes_by_hostgroup_host_hash( $contact, $hostgroup );
is_deeply( $hash, $expected, "Downtimes by host correct" );

$hash =
  Runtime::Searches->downtimes_by_hostgroup_host_hash( $non_admin, $hostgroup );
is_deeply( $hash, $expected, "Downtimes by host correct for non admin contact"
);

diag("Checking can_change_service calls") if ( $ENV{TEST_VERBOSE} );
my $service = Runtime::Service->retrieve(155);
isa_ok( $service, "Runtime::Service", "Fetched test service" );
is(
    $contact->can_change_service($service)->id,
    155, "checking admin access is ok"
);
is(
    $non_admin->can_change_service($service)->id,
    155, "checking non_admin access is ok"
);
is(
    $somehosts->can_change_service($service),
    undef, "checking somehosts access is not ok"
);
is(
    $readonly->can_change_service($service),
    undef, "checking readonly access is not ok"
);
