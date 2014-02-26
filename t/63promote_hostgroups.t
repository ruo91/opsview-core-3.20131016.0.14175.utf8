#!/usr/bin/perl

use Test::More tests => 12;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test;
use Opsview;
use Opsview::Host;
use Opsview::Hostgroup;

my $dbh = Opsview->db_Main;

my $host;
my $expected;

Opsview::Hostgroup->add_lft_rgt_values;

$host     = Opsview::Host->search( name => "host_locally_monitored" )->first;
$_        = $host->hostgroup_1_to_9;
$expected = [qw(Opsview UK Leaf)];
is_deeply( $_, $expected,
    "Hostgroup hierarchy as expected for " . $host->name );

$host     = Opsview::Host->search( name => "resolved_services" )->first;
$_        = $host->hostgroup_1_to_9;
$expected = [qw(Opsview UK2 Leaf2)];
is_deeply( $_, $expected,
    "Hostgroup hierarchy as expected for " . $host->name );

$host     = Opsview::Host->search( name => "opsview" )->first;
$_        = $host->hostgroup_1_to_9;
$expected = [ qw(Opsview UK), "Monitoring Servers" ];
is_deeply( $_, $expected,
    "Hostgroup hierarchy as expected for " . $host->name );

my $hostgroup = Opsview::Hostgroup->search( name => "Leaf" )->first;
$hostgroup->name( "Renamed leaf" );
$hostgroup->parentid(1);
$hostgroup->update;

# Re find it again, otherwise keeps the same object in memory with the old materialized path
$hostgroup = undef;
$hostgroup = Opsview::Hostgroup->search( name => "Renamed leaf" )->first;
is( $hostgroup->matpath, "Opsview,Renamed leaf,", "Materialized path updated"
);

$hostgroup = Opsview::Hostgroup->retrieve(6);
$hostgroup->delete;

$hostgroup = Opsview::Hostgroup->search( name => "Leaf2" )->first;
is( $hostgroup->matpath, "Opsview,Leaf2,", "Mat path updated on delete" );

$hostgroup = Opsview::Hostgroup->create(
    {
        name     => "New hostgroup",
        parentid => 3
    }
);
is(
    $hostgroup->matpath,
    "Opsview,UK,New hostgroup,",
    "Mat path updated on create"
);

my $dup = Opsview::Hostgroup->create(
    {
        name     => "duplicatenameatsamelevel",
        parentid => 1
    }
);
my $thisid = $dup->id;

# Need to create a new sub hostgroup so it is not a leaf
Opsview::Hostgroup->create(
    {
        name     => "subhostgroup",
        parentid => $thisid
    }
);

eval {
    $hostgroup = Opsview::Hostgroup->create(
        {
            name     => "duplicatenameatsamelevel",
            parentid => 1
        }
    );
};
like(
    $@,
    "/system.messages.hostgroup.samenamesameparentclash/",
    "Got system.messages.hostgroup.samenamesameparentclash on create"
);

$hostgroup = Opsview::Hostgroup->create(
    {
        name     => "duplicatenameatsamelevel",
        parentid => $thisid
    }
);
is( $hostgroup->name, "duplicatenameatsamelevel",
    "OK to create hostgroup at different level with same name"
);
is( $hostgroup->parentid->id, $thisid );
isnt( $hostgroup->id, $thisid );

$hostgroup->parentid(1);
eval { $hostgroup->update };
like(
    $@,
    "/system.messages.hostgroup.samenamesameparentclash/",
    "Got system.messages.hostgroup.samenamesameparentclash on update"
);

TODO: {
    local $TODO =
      "Not sure why this fails at the moment - appears to work in UI";
    my $unicode;
    eval {
        $unicode = Opsview::Hostgroup->create(
            {
                name     => "unicodé",
                parentid => $dup->id
            }
        );
    };
    is( $unicode, "Object created" );
    eval { is( $unicode->name, "unicodé" ); };
}

$hostgroup->discard_changes();
