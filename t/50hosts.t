#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib "$Bin/../perl/lib", "$Bin/../lib", "$Bin/../etc", "$Bin/lib";
use Test::More;
use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Host;
use utf8;

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

my $host = Opsview::Host->retrieve_all->first;
$host->notification_interval(35);
$host->update;

is( $host->my_type_is, "host", "Checking my_type_is" );

use Data::Dump qw(dump);
my $data = Opsview::Host->with_advanced_snmptrap_arrayref();
my @hostnames = map { $_->name } @$data;
is_deeply(
    \@hostnames,
    [qw/cisco cisco1 cisco2 cisco3 cisco4/],
    "all snmptrap hosts found"
) || diag( "Got: " . Data::Dump::dump( \@hostnames ) );

my $hostid = $host->id;

is(
    $dbh->selectrow_array(
        "SELECT notification_interval FROM hosts WHERE id = $hostid"),
    35,
    "Changed in DB correctly to 35"
);
is( $host->notification_interval, 35, "And retrieved correctly" );

$host->notification_interval(0);
$host->update;

$host->information( "Some host information" );
$host->update;
is(
    $host->information,
    "Some host information",
    "host information correctly set"
);

$host->information( "Some changed host information" );
$host->update;
is(
    $host->information,
    "Some changed host information",
    "host information correctly updated"
);

is(
    $dbh->selectrow_array(
        "SELECT notification_interval FROM hosts WHERE id = $hostid"),
    0,
    "Changed in DB correctly to 0"
);
is( $host->notification_interval, 0, "And retrieved correctly" );

{
    my @ipv6s = (
        '0000:0000:0000:0000:0000:0000:0000:0001',
        '::1', '2001:db8::1428:57ab',
    );
    foreach my $ipv6 (@ipv6s) {
        eval { $host->ip($ipv6) };
        is( $@,        "",    "IPv6 ip - no exception ($ipv6)" );
        is( $host->ip, $ipv6, "IPv6 ip - set ok ($ipv6)" );
    }
}

eval { $host->other_addresses('bad character here ---> %') };
like(
    $@,
    "/validate_column_values error: other_addresses Opsview::Host other_addresses fails 'regexp' constraint/",
    "Invalid character found in other_addresses"
);

$host->other_addresses( ',allowed,things,,' );
my $expected = [ '', 'allowed', 'things', '', '' ];
my @got = $host->other_addresses_array;
is( $@, "", "Allow commas" );
is_deeply( \@got, $expected, "array list ok" );

$host->other_addresses( ', allowed, things,    ,  ' );
@got = $host->other_addresses_array;
is( $@, "", "Allow commas and spaces" );
is_deeply( \@got, $expected, "array list ok" );

$host->other_addresses( 'allowed-too.hub.altinity' );
is( $@, "", "Hostname looks good too" );

$host->other_addresses( 'allowed-too.hub.altinity,and-me-as-well.hub.altinity'
);
is( $@, "", "Multiple hostnames looks good" );

eval {
    $host->other_addresses(
        'allowed-too.hub.altinity,here@and-me-as-well.hub.altinity'
    );
};
isnt( $@, "", "Do not allow that \@ sign" );

eval {
    $host->other_addresses(
        'allowed-too.hub.altinity, and-me-as-well.hub.altinity'
    );
};
is( $@, "", "Spaces are allowed..." );

eval {
    $host->other_addresses(
        'allowed-too hub altinity, and-me-as-well hub altinity'
    );
};
isnt( $@, "", "...but not within the address" );

$host->other_addresses( '  front-and-back   ' );
is( $@, "", "Allow spaces at front and back" );

$host->other_addresses( '  front-and-back  , left-and-right   ' );
is( $@, "", "And all around the comma" );

eval { $host->other_addresses(',,192.168.101.1,192.168.101.2') };
is( $@, "", "Numeric ips okay" );

{
    my $ipv6 =
      ',0000:0000:0000:0000:0000:0000:0000:0001,::1,2001:db8::1428:57ab';
    eval { $host->other_addresses($ipv6) };
    is( $@,                     "",    "IPv6 other ips - no exception" );
    is( $host->other_addresses, $ipv6, "IPv6 ip - set ok" );
}

$host->other_addresses( '' );
is( $@, "", "Allow making this field blank" );

$host->discard_changes; # Stop warnings

$host->snmp_community( "" );
$host->other_addresses( "" );
$host->snmp_version( "2c" );
$host->snmpv3_username( "" );
$host->snmpv3_authpassword( "" );
$host->snmpv3_authprotocol( "md5" );
$host->snmpv3_privprotocol( "des" );
$host->snmpv3_privpassword( "" );
$host->update;

$host->set_servicechecks_to( qw( 1 5 7 ) );
my @scid_list = map { $_->id } ( $host->servicechecks );
is_deeply( \@scid_list, [ 1, 5, 7 ], "Servicechecks set correctly" );

# Check that remove options get set
$host->set_servicechecks_to( qw( 2 remove-13 18 ) );
my @hsc_objects = Opsview::HostServicecheck->search( hostid => $host->id );
is( $hsc_objects[0]->servicecheckid,      2,  "id correct" );
is( $hsc_objects[0]->remove_servicecheck, 0,  "Not a remove" );
is( $hsc_objects[1]->servicecheckid,      13, "id correct" );
is( $hsc_objects[1]->remove_servicecheck, 1,  "Is a remove" );
is( $hsc_objects[2]->servicecheckid,      18, "id correct" );
is( $hsc_objects[2]->remove_servicecheck, 0,  "Not a remove" );

foreach my $m
  qw(snmp_community snmpv3_username snmpv3_authpassword snmpv3_privpassword) {
    my $M = '$' . uc($m) . '$';
    $host->$m( 'pub$licly' );
    $host->update;

    $_ = $host->expand_host_macros( "check_snmp -C $M" );
    is( $_, "check_snmp -C 'pub\$\$licly'", "$M with \$\$ included" );

    $host->$m( "i'mhappy" );
    $host->update;
    $_ = $host->expand_host_macros( "check_snmp_interfaces -C $M" );
    is(
        $_,
        "check_snmp_interfaces -C 'i'\"'\"'mhappy'",
        "$M with single quotes included"
    );

    $host->$m( 'hesaid"help!"' );
    $host->update;
    $_ = $host->expand_host_macros( "check_snmp -C $M" );
    is(
        $_,
        "check_snmp -C 'hesaid\"help\\!\"'",
        "$M with some other funny chars"
    );

    $host->$m( 'thisisinc\'$100butforyou$20' );
    $host->update;
    $_ = $host->expand_host_macros( "check_snmp -C $M --again $M" );
    is(
        $_,
        "check_snmp -C 'thisisinc'\"'\"'\$\$100butforyou\$\$20' --again 'thisisinc'\"'\"'\$\$100butforyou\$\$20'",
        "$M twice"
    );

}

eval { $host->snmpv3_authpassword("short") };
like( $@, "/fails 'regexp' constraint/", "Error if authpassword too short" );
eval { $host->snmpv3_privpassword("short") };
like( $@, "/fails 'regexp' constraint/", "Error if privpassword too short" );

$host->snmpv3_username( "user" );
$host->snmpv3_authpassword( "authpasswd" );
$host->snmpv3_privpassword( "privpasswd" );
$host->snmp_version( "3" );
$host->update;

our $warning;
$SIG{__WARN__} = sub { $warning = shift };

$_ = $host->expand_host_macros( 'check_ping -H $ADDRESSES$' );
is( $_, "check_ping -H ", "ADDRESSES returns with warnings when empty" );
like(
    $warning,
    '/Macro \$ADDRESSES\$ used, but no other addresses set/',
    "warning propagated"
);

$_ = $host->expand_host_macros( 'check_ping -H $ADDRESS1$' );
is(
    $_,
    "check_ping -H " . $host->ip,
    "ADDRESS1 returns default address when empty"
);

$host->other_addresses( "192.168.0.1, 192.168.1.1, router.hub.altinity," );
$host->update;
$_ = $host->expand_host_macros( 'check_ping -H $ADDRESS1$' );
is( $_, "check_ping -H 192.168.0.1", "ADDRESS1 is good" );
$_ = $host->expand_host_macros( 'check_ping -H $ADDRESS2$' );
is( $_, "check_ping -H 192.168.1.1", "ADDRESS2 is good" );
$_ = $host->expand_host_macros( 'check_ping -H $ADDRESS3$' );
is( $_, "check_ping -H router.hub.altinity", "ADDRESS3 is good" );

$warning = undef;
$_       = $host->expand_host_macros( 'check_ping -H $ADDRESS4$' );
is( $_, "check_ping -H ", "ADDRESS4 is blank" );
is( $warning, undef, "Ensure warning is not raised for the last comma" );

$_ = $host->expand_host_macros( 'check_ping -H $ADDRESS5$' );
is( $_, "check_ping -H " . $host->ip, "unset ADDRESS5 is defaulted correctly"
);

$_ = $host->expand_host_macros( 'check_ping -H $ADDRESSES$' );
is(
    $_,
    "check_ping -H 192.168.0.1,192.168.1.1,router.hub.altinity,",
    "ADDRESSES match"
);

$_ = $host->expand_host_macros(
    'check_snmp_thingie -H $ADDRESS2$ -p $SNMP_VERSION$ -U $SNMPV3_USERNAME$ -A $SNMPV3_AUTHPASSWORD$ -a $SNMPV3_AUTHPROTOCOL$ -x $SNMPV3_PRIVPROTOCOL$ -X $SNMPV3_PRIVPASSWORD$'
);
is(
    $_,
    "check_snmp_thingie -H 192.168.1.1 -p 3 -U 'user' -A 'authpasswd' -a md5 -x des -X 'privpasswd'",
    "Putting it all together"
);

#
# expand_macro tests
#
$_ = $host->expand_link_macros( '$NOT_A_MACRO$' );
is( $_, '$NOT_A_MACRO$', "Non existing macro not expanded" );

$_ = $host->expand_link_macros( 'http://$HOSTNAME$' );
is( $_, 'http://cisco', "HOSTNAME looks good" );

$_ = $host->expand_link_macros( 'http://$HOSTADDRESS$' );
is( $_, 'http://192.168.10.20', "HOSTADDRESS looks good" );

$_ = $host->expand_link_macros( 'http://opsview.org/?par=$HOSTGROUP$' );
is( $_, 'http://opsview.org/?par=Leaf', 'HOSTGROUP looks good' );

$_ = $host->expand_link_macros( '$MONITORED_BY_NAME$' );
is( $_, 'Master Monitoring Server', "MONITORED_BY_NAME looks good" );

$_ = $host->expand_link_macros( '$SNMP_VERSION$' );
is( $_, '3', 'SNMP_VERSION looks good' );

$_ = $host->expand_link_macros( '$SNMP_COMMUNITY$' );
is( $_, 'thisisinc\'$100butforyou$20', 'SNMP_COMMUNITY looks good' );

$_ = $host->expand_link_macros( '$SNMPV3_USERNAME$' );
is( $_, 'user', 'SNMPV3_USERNAME looks good' );

$_ = $host->expand_link_macros( '$SNMPV3_AUTHPASSWORD$' );
is( $_, 'authpasswd', 'SNMPV3_AUTHPASSWORD looks good' );

$_ = $host->expand_link_macros( '$SNMPV3_AUTHPROTOCOL$' );
is( $_, 'md5', 'SNMPV3_AUTHPROTOCOL looks good' );

$_ = $host->expand_link_macros( '$SNMPV3_PRIVPROTOCOL$' );
is( $_, 'des', 'SNMPV3_PRIVPROTOCOL looks good' );

$_ = $host->expand_link_macros( '$SNMPV3_PRIVPASSWORD$' );
is( $_, 'privpasswd', 'SNMPV3_PRIVPASSWORD looks good' );

$_ = $host->expand_link_macros( '$ADDRESSES$' );
is(
    $_,
    '192.168.0.1,192.168.1.1,router.hub.altinity,',
    'ADDRESSES looks good'
);

$_ = $host->expand_link_macros( '$ADDRESS1$' );
is( $_, '192.168.0.1', 'ADDRESS1 looks good' );

$_ = $host->expand_link_macros( '$ADDRESS2$' );
is( $_, '192.168.1.1', 'ADDRESS2 looks good' );

$_ = $host->expand_link_macros( '$ADDRESS3$' );
is( $_, 'router.hub.altinity', 'ADDRESS3 looks good' );

$_ = $host->expand_link_macros(
    'http://$HOSTNAME$/index.pl?p=$HOSTNAME$&a=$HOSTADDRESS$&b=$HOSTADDRESS$'
);
is(
    $_,
    'http://cisco/index.pl?p=cisco&a=192.168.10.20&b=192.168.10.20',
    "More than one macro in string gets substituted"
);

# create a utf hostname (and delete afterwards)
$host = Opsview::Host->find_or_create( { name => "àëòõĉĕ" } );
isa_ok( $host, "Opsview::Host" );
$host->delete;

$host = undef;

# check that constraint starts on 64 characters
my $longname_invalid = "A" x 64;
eval { $host = Opsview::Host->create( { name => $longname_invalid } ) };
is( $host, undef, "Host not created" );
like( $@, "/fails 'regexp' constraint/", "Create error" );

my $longname_valid = "A" x 63;
eval { $host = Opsview::Host->create( { name => $longname_valid } ) };
is( $host->name, $longname_valid, "Host created with 63 chars" );
is( $@, "", "No create error" );

$host = undef;
eval { $host = Opsview::Host->create( { name => 'bad$%^"£%' } ) };
is( $host, undef, "Host not created" );
like( $@, "/fails 'regexp' constraint/", "Create error" );

$host = undef;
eval { $host = Opsview::Host->create( { name => 'Lotsof,,,inname' } ) };
is( $host, undef, "Host not created" );
like( $@, "/fails 'regexp' constraint/", "Create error" );

done_testing();
