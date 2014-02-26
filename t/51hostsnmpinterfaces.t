#!/usr/bin/perl
# Tests to check that snmpinterfaces are added correctly

use Test::More qw(no_plan);

use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test qw(opsview);
use Opsview::Schema;

my $schema = Opsview::Schema->my_connect;

my $host = $schema->resultset("Hosts")->find(2);

$host->set_all_snmpinterfaces(
    [
        {
            name                => "",
            active              => 0,
            throughput_warning  => "3",
            throughput_critical => "6",
            errors_warning      => "",
            errors_critical     => "5",
            discards_warning    => "11",
            discards_critical   => "71",
            indexid             => undef
        },
        {
            name                => "Ethernet1",
            active              => 0,
            throughput_warning  => "",
            throughput_critical => "",
            indexid             => undef
        },
        {
            name                => "Ethernet2",
            active              => 1,
            throughput_warning  => "35664",
            throughput_critical => "44444",
            errors_warning      => "51",
            indexid             => 2
        },
        {
            name                => "Ethernet3",
            active              => 1,
            throughput_warning  => "0",
            throughput_critical => "",
            indexid             => "03"
        },
        {
            name                => "wireless",
            active              => 1,
            throughput_warning  => "",
            throughput_critical => "8",
            discards_critical   => "75",
            indexid             => undef
        },
        {
            name                => "internet",
            active              => 0,
            throughput_warning  => "432",
            throughput_critical => "432",
            indexid             => undef
        },
        {
            name =>
              "ethernet_over_the_longest_piece_of_cable_in_the_world_that_may_use_up_all_the_worlds_resources_in_one_fell_swoop",
            active              => 1,
            throughput_warning  => "80%",
            throughput_critical => "60%",
            indexid             => undef
        },
        {
            name   => "whataboutsomethingwithinvalid'chars%likethishere**\"",
            active => 0,
            throughput_warning  => "",
            throughput_critical => "",
            indexid             => undef
        },
        {
            name   => "funny space at end ",
            active => 0,
        },
    ]
);

my @interfaces = $host->snmpinterfaces;

# Order is different to input order as it is based on interface name
$_ = shift @interfaces;
is( $_->interfacename,       "",                "Default interface" );
is( $_->shortinterfacename,  $_->interfacename, "Short name same" );
is( $_->active,              0,                 "Not activated" );
is( $_->throughput_warning,  "3",               "Warning" );
is( $_->throughput_critical, "6",               "Critical" );
is( $_->errors_warning,      undef,             "No warnings" );
is( $_->errors_critical,     "5",               "Errors critical" );
is( $_->discards_warning,    "11",              "Discards warning" );
is( $_->discards_critical,   "71",              "Discards critical" );
ok( !$_->indexid, "No indexid" );

$_ = shift @interfaces;
is( $_->interfacename, "Ethernet1", "Name correct: " . $_->interfacename );
is( $_->shortinterfacename,  $_->interfacename, "Short name same" );
is( $_->active,              0,                 "Not activated" );
is( $_->throughput_warning,  "",                "No warning" );
is( $_->throughput_critical, "",                "No critical" );
ok( !$_->indexid, "No indexid" );

$_ = shift @interfaces;
is( $_->interfacename, "Ethernet2", "Name correct: " . $_->interfacename );
is( $_->shortinterfacename,  $_->interfacename, "Short name same" );
is( $_->active,              1,                 "Activated" );
is( $_->throughput_warning,  "35664",           "Warning set" );
is( $_->throughput_critical, "44444",           "Critical set" );
is( $_->errors_warning,      51,                "Errors warning" );
is( $_->errors_critical,     "",                "Errors critical" );
is( $_->indexid,             2,                 "Indexid set to 2" );

$_ = shift @interfaces;
is( $_->interfacename, "Ethernet3", "Name correct: " . $_->interfacename );
is( $_->shortinterfacename,  $_->interfacename, "Short name same" );
is( $_->active,              1,                 "Activated" );
is( $_->throughput_warning,  "0",               "Warning set" );
is( $_->throughput_critical, "",                "No critical" );
is( $_->indexid,             3,                 "Indexid set to 3" );

$_ = shift @interfaces;
is(
    $_->interfacename,
    "ethernet_over_the_longest_piece_of_cable_in_the_world_that_may_use_up_all_the_worlds_resources_in_one_fell_swoop",
    "Name correct: " . $_->interfacename
);
is(
    $_->shortinterfacename,
    "ethernet_over_the_longest_piece_of_cable_in_the_w 1",
    "Short name suffixed with an index number"
);
is( $_->active,              1,     "Activated" );
is( $_->throughput_warning,  "80%", "Warning" );
is( $_->throughput_critical, "60%", "Critical" );
ok( !$_->indexid, "No indexid" );

$_ = shift @interfaces;
is(
    $_->interfacename,
    "funny space at end ",
    "Name correct: " . $_->interfacename
);
is(
    $_->shortinterfacename,
    "funny space at end",
    "Short name with space removed"
);
is( $_->active,              0,  "Not activated" );
is( $_->throughput_warning,  "", "Warning" );
is( $_->throughput_critical, "", "Critical" );
ok( !$_->indexid, "No indexid" );

$_ = shift @interfaces;
is( $_->interfacename, "internet", "Name correct: " . $_->interfacename );
is( $_->shortinterfacename,  $_->interfacename, "Short name same" );
is( $_->active,              0,                 "Not activated" );
is( $_->throughput_warning,  "432",             "Warning" );
is( $_->throughput_critical, "432",             "Critical" );
ok( !$_->indexid, "No indexid" );

$_ = shift @interfaces;
is(
    $_->interfacename,
    q{whataboutsomethingwithinvalid'chars%likethishere**"},
    "Name correct: " . $_->interfacename
);
is(
    $_->shortinterfacename,
    "whataboutsomethingwithinvalidcharslikethishere",
    "Short name with chars stripped"
);
is( $_->active, 0, "Not activated" );
ok( !$_->indexid, "No indexid" );

$_ = shift @interfaces;
is( $_->interfacename, "wireless", "Name correct: " . $_->interfacename );
is( $_->shortinterfacename,  $_->interfacename, "Short name same" );
is( $_->active,              1,                 "Activated" );
is( $_->throughput_warning,  "",                "No warning" );
is( $_->throughput_critical, "8",               "Critical" );
is( $_->discards_warning,    "",                "Discards warning" );
is( $_->discards_critical,   75,                "Discards critical" );
ok( !$_->indexid, "No indexid" );

$host->set_all_snmpinterfaces(
    [
        {
            name                => "Ethernet3",
            active              => 0,
            throughput_warning  => "",
            throughput_critical => "",
            indexid             => "03"
        },
        {
            name                => "wireless",
            active              => 1,
            throughput_warning  => "",
            throughput_critical => "",
            indexid             => undef
        },
    ]
);
@interfaces = $host->snmpinterfaces;
is( scalar @interfaces, 2, "Have deleted other interfaces" );

my $bizarre_test_data = [
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 1  ',
        active => 1
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 10  ',
        active => 1
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 11  ',
        active => 1
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 12  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 13  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 14  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 15  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 16  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 17  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 18  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 19  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 2  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 20  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 21  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 22  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 23  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 24  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 25  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 26  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 3  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 4  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 5  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 6  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 7  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 8  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 9  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 1  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 10  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 11  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 12  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 13  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 14  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 15  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 16  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 17  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 18  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 19  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 2  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 20  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 21  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 22  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 23  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 24  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 25  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 26  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 3  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 4  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 5  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 6  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 7  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 8  '
    },
    {
        name =>
          'Nortel Ethernet Routing Switch 4526GTX Module - Unit 2 Port 9  '
    },
    { name => 'Nortel Ethernet Routing Switch 4526GTX Module - VLAN 1' }
];
$host->set_all_snmpinterfaces($bizarre_test_data);
@interfaces = $host->snmpinterfaces;
is( scalar @interfaces, 53, "Changed which interfaces are saved" );
is(
    $interfaces[0]->interfacename,
    "Nortel Ethernet Routing Switch 4526GTX Module - Unit 1 Port 1  ",
    "Name not truncated"
);

$host->update( { enable_snmp => 1 } );
my @vars = $host->host_attributes_for_name( "INTERFACE" );
is(
    scalar @vars,
    3,
    "Got 3 active interfaces - actually testing that missing a default line doesn't cause a failure"
);
