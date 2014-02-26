#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";

use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Host;
use Opsview::CRUD::Host;
use Opsview::Auditlog;

use Test::More tests => 19;

my $h = Opsview::CRUD::Host->retrieve(2)->as_hash;

my $expected = {
    alias           => "",
    check_attempts  => 2,
    check_command   => { id => 1 },
    check_interval  => 0,
    check_period    => { id => 1 },
    enable_snmp     => 1,
    event_handler   => '',
    hostgroup       => { id => 2 },
    hosttemplates   => [ { id => 7 } ],
    http_admin_port => undef,
    http_admin_url  => undef,
    icon                   => { name => "SYMBOL - Wireless network" },
    ip                     => "opsviewdev1.der.altinity",
    keywords               => [],
    use_nmis               => 0,
    monitored_by           => { id   => 1 },
    name                   => "opsviewdev1",
    nmis_node_type         => "router",
    notification_interval  => 60,
    notification_options   => "u,d,r",
    notification_period    => { id   => 1 },
    other_addresses        => "",
    parents                => [],
    use_rancid             => 0,
    use_mrtg               => 1,
    rancid_autoenable      => 0,
    rancid_connection_type => "ssh",
    rancid_username        => undef,
    rancid_password        => undef,
    rancid_vendor          => undef,
    retry_check_interval   => 1,
    servicecheckexceptions => [],
    servicechecks =>
      [ { id => 6 }, { id => 22 }, { id => 29 }, { id => 91 }, { id => 103 } ],
    servicechecktimedoverrideexceptions => [],
    flap_detection_enabled              => 1,
    snmp_community                      => "",
    snmp_port                           => 161,
    snmp_version                        => "2c",
    snmpv3_privprotocol                 => undef,
    snmpv3_authprotocol                 => undef,
    snmpv3_privpassword                 => "",
    snmpv3_authpassword                 => "",
    snmpv3_username                     => "",
    snmpinterfaces                      => [],
    snmptrap_tracing                    => 0,
};

is_deeply( $h, $expected, "Hash as expected" )
  || diag( "Full hash:" . Data::Dump::dump($h) );

my $hg = Opsview::Hostgroup->search( name => "Monitoring Servers" )->first;
my $host = {
    'name'      => 'bob',
    'ip'        => '127.0.0.1',
    'hostgroup' => { 'name' => 'Monitoring Servers' },
    'icon'      => { name => "LOGO - FreeBSD" },
};
my $object = Opsview::CRUD::Host->do_create($host);

isa_ok( $object, "Opsview::CRUD::Host", "Host created" );
$_ = Opsview::Host->search( { name => "bob" } )->first;
is( $_->ip,            "127.0.0.1", "IP set correctly" );
is( $_->hostgroup->id, $hg->id,     "Hostgroup set correctly" );

$host = {
    name  => "bob2",
    clone => { name => "bob" },
};
$object = Opsview::CRUD::Host->do_create($host);
isa_ok( $object, "Opsview::CRUD::Host", "Host created with clone by name" );
$_ = Opsview::Host->search( { name => "bob2" } )->first;
is( $_->ip,            "127.0.0.1", "IP still same as old" );
is( $_->hostgroup->id, $hg->id,     "Hostgroup set correctly" );

$host = {
    name                  => "bob3",
    clone                 => { id => 2 },
    notification_interval => 20,
};
$object = Opsview::CRUD::Host->do_create($host);
isa_ok( $object, "Opsview::CRUD::Host", "Host created with clone by id" );
$_                = Opsview::Host->search( { name => "bob3" } )->first;
$h                = $_->as_hash;
$expected->{name} = "bob3";
$expected->{notification_interval} = 20;
is_deeply( $h, $expected, "Object hashes as expected" );

$host = {
    name          => "bob-child",
    clone         => { id => 2 },
    parents       => [ { name => "bob3" }, { name => "bob2" } ],
    servicechecks => [],
};
$object = Opsview::CRUD::Host->do_create($host);
isa_ok( $object, "Opsview::CRUD::Host",
    "Host created with clone by id and extra parents"
);
$_                = Opsview::Host->search( { name => "bob-child" } )->first;
$h                = $_->as_hash;
$expected->{name} = "bob-child";
$expected->{notification_interval} = 60;

# The order below is slightly different to the parents directive above
# We order by the id number
$expected->{parents} = [
    { id => Opsview::Host->search( name => "bob2" )->first->id },
    { id => Opsview::Host->search( name => "bob3" )->first->id }
];
$expected->{servicechecks} = [];
is_deeply( $h, $expected, "Object hashes as expected" );

$host = { name => "badman", };
eval { $object = Opsview::CRUD::Host->do_create($host) };
like( $@, "/^Field ip is mandatory/", "Failed creation when missing data" );

$host = {
    name  => "bob3",
    clone => { id => 2 },
};
eval { $object = Opsview::CRUD::Host->do_create($host) };
like(
    $@,
    "/Duplicate entry 'bob3' for key/",
    "Failed creation due to non-unique column"
);

$host = {
    name          => "bob4",
    clone         => { id => 2 },
    check_command => { name => "not_really_one" },
};
eval { $object = Opsview::CRUD::Host->do_create($host) };
like(
    $@,
    "/^Cannot find object check_command with name 'not_really_one'/",
    "Failed creation due to missing cross reference"
);

$host = {
    name          => "bob4",
    clone         => { id => 2 },
    check_command => { id => 2030485698 },
};
eval { $object = Opsview::CRUD::Host->do_create($host) };
like(
    $@,
    "/Cannot find object check_command with id=2030485698/",
    "Failed creation due to integrity constraint"
);

$host = {
    name  => "bob4",
    clone => { name => "never existed" },
};
eval { $object = Opsview::CRUD::Host->do_create($host) };
like(
    $@,
    "/^Object name='never existed' not found/",
    "Failed creation due to missing clone host"
);

$host = {
    name  => "bob4",
    clone => { id => 23498234 },
};
eval { $object = Opsview::CRUD::Host->do_create($host) };
like(
    $@,
    "/^Object id='23498234' not found/",
    "Failed creation due to missing clone host by id"
);

$object = Opsview::CRUD::Host->do_retrieve(2);
$_      = Opsview::Host->retrieve(2);
is_deeply( $object, $_, "Same object" );

$object->do_delete;
eval { $_ = Opsview::Host->retrieve(2) };
is( $_, undef, "Object does not exist anymore" );
