#!perl

# This is used to test the XML, to prove that xml is being converted into hashes correctly

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";

use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Host;
use Opsview::XML;

use XML::LibXML;
my $parser = XML::LibXML->new;
my $rngschema =
  XML::LibXML::RelaxNG->new(
    location => "/usr/local/nagios/share/xml/opsview.rng" );

use Test::More tests => 9;

my $h       = Opsview::Host->retrieve(2);
my $hash    = $h->as_hash;
my $xml     = $h->as_xml;
my $raw_xml = qq{    <name>opsviewdev1</name>
    <alias></alias>
    <check_attempts>2</check_attempts>
    <check_command>
      <id>1</id>
    </check_command>
    <check_interval>0</check_interval>
    <check_period>
      <id>1</id>
    </check_period>
    <enable_snmp>1</enable_snmp>
    <event_handler></event_handler>
    <flap_detection_enabled>1</flap_detection_enabled>
    <hostgroup>
      <id>2</id>
    </hostgroup>
    <hosttemplates>
      <hosttemplate>
        <id>7</id>
      </hosttemplate>
    </hosttemplates>
    <icon>
      <name>SYMBOL - Wireless network</name>
    </icon>
    <ip>opsviewdev1.der.altinity</ip>
    <keywords>
    </keywords>
    <monitored_by>
      <id>1</id>
    </monitored_by>
    <nmis_node_type>router</nmis_node_type>
    <notification_interval>60</notification_interval>
    <notification_options>u,d,r</notification_options>
    <notification_period>
      <id>1</id>
    </notification_period>
    <other_addresses></other_addresses>
    <parents>
    </parents>
    <rancid_autoenable>0</rancid_autoenable>
    <rancid_connection_type>ssh</rancid_connection_type>
    <retry_check_interval>1</retry_check_interval>
    <servicecheckexceptions>
    </servicecheckexceptions>
    <servicechecks>
      <servicecheck>
        <id>6</id>
      </servicecheck>
      <servicecheck>
        <id>22</id>
      </servicecheck>
      <servicecheck>
        <id>29</id>
      </servicecheck>
      <servicecheck>
        <id>91</id>
      </servicecheck>
      <servicecheck>
        <id>103</id>
      </servicecheck>
    </servicechecks>
    <servicechecktimedoverrideexceptions>
    </servicechecktimedoverrideexceptions>
    <snmp_community></snmp_community>
    <snmp_port>161</snmp_port>
    <snmp_version>2c</snmp_version>
    <snmpinterfaces>
    </snmpinterfaces>
    <snmptrap_tracing>0</snmptrap_tracing>
    <snmpv3_authpassword></snmpv3_authpassword>
    <snmpv3_privpassword></snmpv3_privpassword>
    <snmpv3_username></snmpv3_username>
    <use_mrtg>1</use_mrtg>
    <use_nmis>0</use_nmis>
    <use_rancid>0</use_rancid>};
my $full_xml = "<opsview>\n  <host>\n$raw_xml\n  </host>\n</opsview>\n";
is( $xml, $full_xml, "XML as expected" );
eval { $_ = $rngschema->validate( $parser->parse_string($xml) ) };
is( $_, 0, "XML is valid in schema" )
  || diag( "You most probably need to update the schema - $@" );

# Hashes serialized in XML have keys with undef values removed.
# We do that here
map { delete $hash->{$_} unless defined $hash->{$_} } ( keys %$hash );

my $new_hash = Opsview::Host->from_xml($xml);
is_deeply( $new_hash, $hash, "Got same hash back" );

my $input = Opsview::XML->new;
$input->deserialize;
is( $input->error, "No data in body to deserialize", "Correct error" );

$input = Opsview::XML->new;
$input->body( "<opsview><host action='create'>$raw_xml</host></opsview>" );
$input->deserialize;
$new_hash = $input->data;
is_deeply( $new_hash, $hash, "Get same object" );

$input = Opsview::XML->new;
$input->body(
    '<opsview><host action="create"><clone><name>bob</name></clone></host></opsview>'
);
$input->deserialize;
my $expected = { clone => { name => "bob" }, };
is( $input->action, "create", "Creation" );
is_deeply( $input->data, $expected, "Expected hash" );

$input = Opsview::XML->new;
$input->body(
    qq{
<opsview><host action="create"><name>bob2</name><ip>10.10.10.10</ip><hostgroup><name>Monitoring Servers</name></hostgroup>
<check_command><name>ping</name></check_command>
<servicechecks>
 <servicecheck><id>35</id></servicecheck>
 <servicecheck><name>HTTP</name></servicecheck>
 <servicecheck><id>7</id></servicecheck>
 <servicecheck><name>AFS</name></servicecheck>
</servicechecks>
<hosttemplates>
</hosttemplates>
</host></opsview>
}
);
$input->deserialize;
is( $input->action, "create", "Creation" );
$expected = {
    name          => "bob2",
    ip            => "10.10.10.10",
    hostgroup     => { name => "Monitoring Servers" },
    check_command => { name => "ping" },
    servicechecks =>
      [ { id => 35 }, { name => "HTTP" }, { id => 7 }, { name => "AFS" } ],
    hosttemplates => [],
};
is_deeply( $input->data, $expected, "Correct interpretation of lists" );
