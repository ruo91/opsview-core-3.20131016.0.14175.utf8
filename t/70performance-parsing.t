#!/usr/bin/perl

use Test::More no_plan;

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use Opsview;
use Opsview::Performanceparsing;
use Data::Dump;

is( Opsview::Performanceparsing->init, 1, "Initialised okay" );

my ( $got, $expected );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "Check Memory",
    output =>
      "Memory: total 1024 MB, active 121 MB, inactive 790 MB, wired: 91 MB, free: 22 MB (2%)",
    perfdata => "",
);

$expected = [
    {
        uom   => "",
        label => "total",
        value => "1024"
    },
    {
        uom   => "",
        label => "active",
        value => 121
    },
    {
        uom   => "",
        label => "inactive",
        value => 790
    },
    {
        uom   => "",
        label => "wired",
        value => 91
    },
    {
        uom   => "",
        label => "free",
        value => 22
    },
];
is_deeply( $got, $expected, "Parsed via output correctly" )
  || diag( Data::Dump::dump($got) );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "dummy",
    output =>
      "Memory: total 1024 MB, active 121 MB, inactive 790 MB, wired: 91 MB, free: 22 MB (2%)",
    perfdata => "utilisation=41",
);
$expected = [
    {
        uom      => "",
        label    => "utilisation",
        value    => "41",
        warning  => undef,
        critical => undef,
        max      => undef,
        min      => undef
    },
];
TODO: {
    local $TODO = "Not true yet - only uses perfdata if no matches occur";
    is_deeply( $got, $expected, "Parsed via perfdata in preference to output"
    );
}

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "dummy",
    output      => "OK - load average: 0.05, 0.03, 0.00",
    perfdata =>
      "load1=0.051;5.000;9.000;0; load5=0.033;5.000;9.000;0; load15=0.003;5.000;9.000;0;",
);
$expected = [
    {
        uom   => "",
        label => "load1",
        value => "0.051"
    },
    {
        uom   => "",
        label => "load5",
        value => "0.033"
    },
    {
        uom   => "",
        label => "load15",
        value => "0.003"
    },
];
is_deeply( $got, $expected, "Parsed via perfdata correctly" )
  || diag( Data::Dump::dump($got) );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "TCP/IP",
    output      => "CRITICAL - Host Unreachable",
    perfdata    => "",
);
$expected = [
    {
        uom   => "",
        label => "losspct",
        value => "100"
    },
    {
        uom   => "",
        label => "rta",
        value => "U"
    },
];
is_deeply( $got, $expected, "Parsed Host Unreachable errors" );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "TCP/IP",
    output      => "CRITICAL - Time to live exceeded",
    perfdata    => "",
);
is_deeply( $got, $expected, "Parsed Time to live exceeded errors" );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "TCP/IP",
    output      => "PING CRITICAL - Packet loss = 100%",
    perfdata    => "",
);
is_deeply( $got, $expected, "Parsed packet loss 100% errors" );

$expected = [
    {
        uom   => "",
        label => "losspct",
        value => "0"
    },
    {
        uom   => "",
        label => "rta",
        value => "0.00116"
    },
];
$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "TCP/IP",
    output      => "PING CRITICAL - Packet loss = 0%, RTA = 1.16 ms",
    perfdata    => "",
);
is_deeply( $got, $expected, "Parsed normal ping result correctly" );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "Check Memory",
    output =>
      "Memory: total 1024 MB, active 121 MB, inactive 790 MB, wired: 91 MB, free: 22 MB (2%)",
    perfdata => "",
);

$expected = [
    {
        uom   => "",
        label => "total",
        value => "1024"
    },
    {
        uom   => "",
        label => "active",
        value => 121
    },
    {
        uom   => "",
        label => "inactive",
        value => 790
    },
    {
        uom   => "",
        label => "wired",
        value => 91
    },
    {
        uom   => "",
        label => "free",
        value => 22
    },
];
is_deeply( $got, $expected, "Parsed via output correctly" );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "dummy",
    output =>
      "Memory: total 1024 MB, active 121 MB, inactive 790 MB, wired: 91 MB, free: 22 MB (2%)",
    perfdata => "utilisation=41",
);
$expected = [
    {
        uom      => "",
        label    => "utilisation",
        value    => "41",
        warning  => undef,
        critical => undef,
        max      => undef,
        min      => undef
    },
];
TODO: {
    local $TODO = "Not true yet - only uses perfdata if no matches occur";
    is_deeply( $got, $expected, "Parsed via perfdata in preference to output"
    );
}

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "dummy",
    output      => "OK - load average: 0.05, 0.03, 0.00",
    perfdata =>
      "load1=0.051;5.000;9.000;0; load5=0.033;5.000;9.000;0; load15=0.003;5.000;9.000;0;",
);
$expected = [
    {
        uom   => "",
        label => "load1",
        value => "0.051"
    },
    {
        uom   => "",
        label => "load5",
        value => "0.033"
    },
    {
        uom   => "",
        label => "load15",
        value => "0.003"
    },
];
is_deeply( $got, $expected, "Parsed via perfdata correctly" )
  || diag( Data::Dump::dump($got) );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "TCP/IP",
    output      => "CRITICAL - Host Unreachable",
    perfdata    => "",
);
$expected = [
    {
        uom   => "",
        label => "losspct",
        value => "100"
    },
    {
        uom   => "",
        label => "rta",
        value => "U"
    },
];
is_deeply( $got, $expected, "Parsed Host Unreachable errors" );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "TCP/IP",
    output      => "CRITICAL - Time to live exceeded",
    perfdata    => "",
);
is_deeply( $got, $expected, "Parsed Time to live exceeded errors" );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "TCP/IP",
    output      => "PING CRITICAL - Packet loss = 100%",
    perfdata    => "",
);
is_deeply( $got, $expected, "Parsed packet loss 100% errors" );

$expected = [
    {
        uom   => "",
        label => "losspct",
        value => "0"
    },
    {
        uom   => "",
        label => "rta",
        value => "0.00116"
    },
];
$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "TCP/IP",
    output      => "PING CRITICAL - Packet loss = 0%, RTA = 1.16 ms",
    perfdata    => "",
);
is_deeply( $got, $expected, "Parsed normal ping result correctly" );

$got = Opsview::Performanceparsing->parseperfdata(
    servicename => "Disk: /",
    output      => "DISK OK - free space: / 1690 MB (50% inode=61%):",
    perfdata    => "/=1661MB;3354;3460;0;3531",
);
$expected = [
    {
        uom   => "MB",
        label => "root",
        value => "1661"
    }
];
is_deeply( $got, $expected, "Parsed via perfdata correctly" )
  || diag( Data::Dump::dump($got) );
