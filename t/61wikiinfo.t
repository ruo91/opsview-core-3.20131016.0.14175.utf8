#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc", "$Bin/lib";
use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Hostinfo;
use Opsview::Host;
use utf8;
use Opsview::Schema;

my $schema = Opsview::Schema->my_connect;

my $utfstring = 'dénér Óberne';

my $host      = Opsview::Host->retrieve(1);
my $host_dbic = $schema->resultset("Hosts")->find(1);
foreach my $obj ( $host, $host_dbic ) {
    is( $obj->name, "opsview" );
    is( $obj->information, undef, "No default text" );
}

$host->information($utfstring);
$host->update;

is( $host->information, $utfstring, "Got utf8 string" );
TODO: {
    local $TODO = "UTF8 support not working with DBIx::Class";
    is( $host_dbic->information, $utfstring, "Got utf8 string" );
}

my $hg      = Opsview::Hostgroup->retrieve(2);
my $hg_dbic = $schema->resultset("Hostgroups")->find(2);
foreach my $obj ( $hg, $hg_dbic ) {
    is( $obj->name, "Monitoring Servers" );
    is( $obj->information, undef, "No default text for hostgroup" );
}

$hg->information($utfstring);
$hg->update;

is( $hg->information, $utfstring, "Got utf8 string" );
TODO: {
    local $TODO = "UTF8 support not working with DBIx::Class";
    is( $hg_dbic->information, $utfstring, "Got utf8 string" );
}
