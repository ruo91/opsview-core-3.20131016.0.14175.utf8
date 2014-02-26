#!/usr/bin/perl

use Test::More tests => 9;

use Test::Deep;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Runtime;
use Runtime::Searches;
use Opsview;
use Opsview::Schema;
use Opsview::Test;

my $dbh = Runtime->db_Main;

my $schema = Opsview::Schema->my_connect;

my $admin =
  $schema->resultset("Contacts")->search( { name => "admin" } )->first;
my $non_admin =
  $schema->resultset("Contacts")->search( { name => "nonadmin" } )->first;
my $somehosts =
  $schema->resultset("Contacts")->search( { name => "somehosts" } )->first;
my $readonly =
  $schema->resultset("Contacts")->search( { name => "readonly" } )->first;

my ( $list, $expected );

$expected = [
    {
        icon  => "cisco",
        ip    => "192.168.10.20",
        name  => "cisco",
        alias => 'cisco',
    },
    {
        icon  => "cisco",
        ip    => "192.168.10.23",
        name  => "cisco1",
        alias => 'cisco1',
    },
    {
        icon  => "cisco",
        ip    => "192.168.10.22",
        name  => "cisco2",
        alias => 'cisco2',
    },
    {
        icon  => "cisco",
        ip    => "192.168.10.22",
        name  => "cisco3",
        alias => 'cisco3',
    },
    {
        icon  => "cisco",
        ip    => "not_a_real_host",
        name  => "cisco4",
        alias => 'cisco4',
    },
    {
        icon  => "",
        ip    => "",
        name  => "cloned",
        alias => 'cloned',
    },
    {
        icon  => "dragonflybsd",
        ip    => "",
        name  => "cloned2",
        alias => 'cloned2',
    },
    {
        icon  => "debian",
        ip    => "192.168.50.10",
        name  => "doesnt_exist_1",
        alias => 'doesnt_exist_1',
    },
    {
        icon  => "debian",
        ip    => "192.168.50.11",
        name  => "doesnt_exist_2",
        alias => 'doesnt_exist_2',
    },
    {
        icon  => "dragonflybsd",
        ip    => "hostname1",
        name  => "host_locally_monitored",
        alias => 'host_locally_monitored',
    },
    {
        icon  => "debian",
        ip    => "not_in_opsview_db",
        name  => "missing_from_configuration",
        alias => 'missing_from_configuration',
    },
    {
        icon  => "wireless",
        ip    => "monitored_by_clusterip",
        name  => "monitored_by_cluster",
        alias => 'Host to be monitored by slave',
    },
    {
        icon  => "vmware",
        ip    => "monitored_by_slave",
        name  => "monitored_by_slave",
        alias => 'Host to be monitored by slave',
    },
    {
        icon  => "opsview",
        ip    => "opslave",
        name  => "opslave",
        alias => 'Slave',
    },
    {
        icon  => "opsview",
        ip    => "localhost",
        name  => "opsview",
        alias => 'Opsview Master Server',
    },
    {
        icon  => "wireless",
        ip    => "opsviewdev1.der.altinity",
        name  => "opsviewdev1",
        alias => '',
    },
    {
        icon  => "vpn",
        ip    => "192.168.101.46",
        name  => "opsviewdev46",
        alias => '',
    },
    {
        icon => "vmware",
        ip   => "resolved_services",
        name => "resolved_services",
        alias =>
          'Host with services based on templates, exceptions and timed exce',
    },
];

$list = Runtime::Searches->list_hosts_by_contact( $admin, { q => "o" } );
cmp_deeply( $list, $expected, "Got expected list for admin contact" );

$list = Runtime::Searches->list_hosts_by_contact( $readonly, { q => "o" } );
cmp_deeply( $list, $expected, "Got same list for readonly contact" );

# Same as above, but host cloned has been removed. This is because there are
# no services on that host, so it is effectively missing
$expected = [
    {
        icon  => "cisco",
        ip    => "192.168.10.20",
        name  => "cisco",
        alias => 'cisco',
    },
    {
        icon  => "cisco",
        ip    => "192.168.10.23",
        name  => "cisco1",
        alias => 'cisco1',
    },
    {
        icon  => "cisco",
        ip    => "192.168.10.22",
        name  => "cisco2",
        alias => 'cisco2',
    },
    {
        icon  => "cisco",
        ip    => "192.168.10.22",
        name  => "cisco3",
        alias => 'cisco3',
    },
    {
        icon  => "cisco",
        ip    => "not_a_real_host",
        name  => "cisco4",
        alias => 'cisco4',
    },
    {
        icon  => "dragonflybsd",
        ip    => "",
        name  => "cloned2",
        alias => 'cloned2',
    },
    {
        icon  => "debian",
        ip    => "192.168.50.10",
        name  => "doesnt_exist_1",
        alias => 'doesnt_exist_1',
    },
    {
        icon  => "debian",
        ip    => "192.168.50.11",
        name  => "doesnt_exist_2",
        alias => 'doesnt_exist_2',
    },
    {
        icon  => "dragonflybsd",
        ip    => "hostname1",
        name  => "host_locally_monitored",
        alias => 'host_locally_monitored',
    },
    {
        icon  => "vmware",
        ip    => "monitored_by_slave",
        name  => "monitored_by_slave",
        alias => 'Host to be monitored by slave',
    },
    {
        icon  => "opsview",
        ip    => "opslave",
        name  => "opslave",
        alias => 'Slave',
    },
    {
        icon  => "opsview",
        ip    => "localhost",
        name  => "opsview",
        alias => 'Opsview Master Server',
    },
    {
        icon => "vmware",
        ip   => "resolved_services",
        name => "resolved_services",
        alias =>
          'Host with services based on templates, exceptions and timed exce',
    },
];

$list = Runtime::Searches->list_hosts_by_contact( $non_admin, { q => "o" } );
cmp_deeply(
    $list,
    $expected,
    "Got slightly different list for non-admin contact due to a host without any services"
);

$expected = [
    {
        name  => "monitored_by_slave",
        icon  => "vmware",
        ip    => "monitored_by_slave",
        alias => 'Host to be monitored by slave',
    },
];

$list = Runtime::Searches->list_hosts_by_contact( $somehosts, { q => "o" } );
cmp_deeply( $list, $expected, "Got different list for readonly contact" );

# Check permissions for hosts/services
ok(
    $admin->can_change_object_by_name( { hostname => "fakename" } ),
    "Admin user can change anything"
);
ok(
    $somehosts->can_change_object_by_name(
        { hostname => "monitored_by_slave" }
    ),
    "Somehosts user can change monitored_by_slave host"
);
ok(
    $somehosts->can_change_object_by_name(
        {
            hostname    => "monitored_by_slave",
            servicename => "/"
        }
    ),
    "...and service"
);
ok(
    !$somehosts->can_change_object_by_name( { hostname => "rubbish" } ),
    "But not a fake host"
);
ok(
    !$readonly->can_change_object_by_name(
        { hostname => "monitored_by_slave" }
    ),
    "Readonly can't change this host"
);
