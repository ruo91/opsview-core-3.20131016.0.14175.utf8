#!/usr/bin/env perl
# Tests for Opsview::ResultSet::Servicechecks

use Test::More qw(no_plan);

use Carp::Clan qw(verbose);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);

my $schema = Opsview::Schema->my_connect;

my $obj;
my $expected;
my $rs = $schema->resultset( "Servicechecks" );

$obj = $rs->find( { name => "Check Memory" } );
isa_ok( $obj, "Opsview::Schema::Servicechecks" );

is( $obj->hosts->count,         4, );
is( $obj->hosttemplates->count, 2 );

$rs->add_dependency_levels;
my %dependency_level =
  map { ( $_->name, $_->dependency_level ) }
  ( $rs->search( { dependency_level => { ">" => 0 } } ) );
$expected = {
    Disk               => 1,
    "Interface Poller" => 1,
    JBoss              => 1,
    "Opsview Agent"    => 2,
    "SNMP Agent"       => 2,
};
is_deeply( \%dependency_level, $expected, "Got correct dependency level" )
  || diag( Data::Dump::dump( \%dependency_level ) );

my @ordered_by_dependency_level = map { $_->name } (
    $rs->search(
        {},
        {
            columns  => "name",
            rows     => 7,
            page     => 1,
            order_by => [ { "-desc" => "dependency_level" }, "name" ]
        }
    )
);
$expected = [
    "Opsview Agent", "SNMP Agent", "Disk", "Interface Poller",
    "JBoss",         "/",          "/boot",
];
is_deeply( \@ordered_by_dependency_level,
    $expected, "Got sorted in right order" )
  || diag( Data::Dump::dump( \@ordered_by_dependency_level ) );

# Check searches based on hosts
my $scs_for_host1 = $rs->search(
    { "hostservicechecks.hostid" => { "-in" => [ 12, 20 ] } },
    {
        join     => "hostservicechecks",
        distinct => 1
    }
);
my @sc_names;
while ( my $sc = $scs_for_host1->next ) {
    push @sc_names, $sc->name;
}
is_deeply(
    \@sc_names,
    [
        "Check Loadavg", "Cluster-node", "DNS",    "HTTP",
        "Mysql Query",   "snmp poll",    "TCP/IP", "Z Drive"
    ],
    "got all service checks via host"
) || diag( Data::Dump::dump(@sc_names) );

$scs_for_host1 = $rs->search(
    { "hosthosttemplates.hostid" => { "-in" => [ 12, 20 ] } },
    {
        distinct => 1,
        join     => {
            "hosttemplateservicechecks" =>
              { "hosttemplateid" => "hosthosttemplates" }
        }
    }
);
@sc_names = ();
while ( my $sc = $scs_for_host1->next ) {
    push @sc_names, $sc->name;
}
is_deeply(
    \@sc_names,
    [
        "/",                "Check Loadavg",
        "Check Memory",     "Interface",
        "Interface Poller", "SNMP Agent",
        "SSH",              "TCP/IP",
        "VNC"
    ],
    "got all service checks via host template"
) || diag( Data::Dump::dump(@sc_names) );

@sc_names = ();
foreach my $sc ( $rs->list_servicechecks_by_host( [ 12, 20 ] ) ) {
    push @sc_names, $sc->name;
}
is_deeply(
    \@sc_names,
    [
        "/",            "Check Loadavg",
        "Check Memory", "Cluster-node",
        "DNS",          "HTTP",
        "Interface",    "Interface Poller",
        "Mysql Query",  "SNMP Agent",
        "snmp poll",    "SSH",
        "TCP/IP",       "VNC",
        "Z Drive"
    ],
    "got all service checks via combined host + host template"
) || diag( Data::Dump::dump(@sc_names) );

is( $rs->search( { name => "NewCheck" } )->count, 0 );

$rs->synchronise(
    {
        name         => "NewCheck",
        checktype    => 1,
        servicegroup => { name => "Operations" },
        plugin       => "check_apt"
    }
);

is( $rs->search( { name => "NewCheck" } )->count, 1 );

$obj = $rs->find( { name => "NewCheck" } );
is( $obj->uncommitted, 1, "Check uncommitted flag set" );

#$rs->synchronise( { name => "NewCheck", description => "Test generated new check", check_period => { name => "24x7" } } );
$rs->synchronise(
    {
        name        => "NewCheck",
        description => "Test generated new check"
    }
);
$obj = $rs->find( { name => "NewCheck" } );

# Check default values
is( $obj->check_period,     "24x7" );
is( $obj->servicegroup->id, 1 );
is( $obj->checktype->id, 1, "Active check" );
is( $obj->plugin->name, "check_apt" );

$rs->synchronise(
    {
        name                => "NewCheck",
        check_period        => { id => 2 },
        notification_period => { name => "nonworkhours" },
        servicegroup        => { name => "operations" },
        delete              => 1
    }
);
$obj = $rs->find( { name => "NewCheck" } );
isa_ok(
    $obj,
    "Opsview::Schema::Servicechecks",
    "Servicecheck exists and not deleted by errant delete attribute"
);
is( $obj->check_period,        "workhours" );
is( $obj->notification_period, "nonworkhours" );
is( $obj->servicegroup->name,  "Operations" );

$rs->synchronise(
    {
        name                => "NewCheck",
        event_handler       => "knightrider",
        check_period        => { id => 2 },
        notification_period => { name => "nonworkhours" }
    }
);
$obj = $rs->find( { name => "NewCheck" } );
is( $obj->event_handler, "knightrider" );
is( $obj->servicegroup->name, "Operations",
    "Confirm service group hasn't changed"
);

my $webcheck = $rs->synchronise(
    {
        name         => "HTTP port 10000",
        checktype    => 1,
        servicegroup => { name => "Freshness checks" },
        plugin       => "check_apt"
    }
);
isnt(
    $rs->find( { name => "HTTP port 10000" } ),
    undef, "Servicecheck created created"
);

$obj = $rs->synchronise(
    {
        name         => "NewCheck  ",
        dependencies => [ { id => $webcheck->id }, { name => "NewCheck" } ],
        attribute    => undef,
        keywords =>
          [ { name => "disabled" }, { name => "newlycreatedkeyword" } ],
        check_period          => { id   => 2 },
        notification_period   => { name => "nonworkhours" },
        notification_interval => 60,
        notification_options  => "w,c,r",
        retry_check_interval  => 1,
        check_interval        => 33,
        servicegroup          => { name => "Operations" },
        checktype             => 1,
        markdown_filter       => 0,
        description           => "Opsview test sc",
    }
);

my @keywords = $obj->keywords;
is( scalar @keywords,   2,                     "Got 2 keywords" );
is( $keywords[0]->name, "disabled",            "Got keyword1" );
is( $keywords[1]->name, "newlycreatedkeyword", "Got keyword2" );

my $child = $rs->synchronise(
    {
        name         => "childDepOfNewCheck",
        checktype    => 1,
        servicegroup => 2,
        plugin       => "check_apt",
        dependencies => [ $obj->id ]
    }
);
is( $child->dependencies->first->name, "NewCheck", "Added a child" );

is( $obj->affects->first->id, $child->id, "Got child" );

$webcheck->delete;
is(
    $rs->find( { name => "HTTP port 10000" } ),
    undef, "HTTP port 10000 deleted"
);
$obj->discard_changes;
is( $obj->dependencies->first, undef, "No dependency for object now" );

$child->delete;
is( $rs->find( { name => "childDepOfNewCheck" } ), undef, "Child removed" );

$rs->synchronise(
    {
        name         => "CheckMemoryDup",
        description  => "Dup of Check Memory",
        servicegroup => { name => "freshness checks" },
        keywords     => [
            { name => "bobgeldof" },
            { name => "elvispresley" },
            { name => "allhosts" }
        ],
        check_period            => { id   => 2 },
        check_attempts          => 6,
        check_interval          => 22,
        checktype               => 1,
        retry_check_interval    => 2,
        plugin                  => { name => "check_nrpe" },
        invertresults           => 1,
        notification_options    => "n",
        notification_period     => undef,
        notification_interval   => undef,
        attribute               => { name => "URL" },
        flap_detection_enabled  => 0,
        volatile                => 2,
        event_handler           => "",
        markdown_filter         => 1,
        oid                     => "SNMP:MIB-2:Stuff",
        critical_comparison     => "eq",
        critical_value          => "54",
        warning_value           => "100",
        warning_comparison      => ">",
        calculate_rate          => "per_second",
        label                   => "graphlabel",
        check_freshness         => 1,
        freshness_type          => "set_stale",
        stale_state             => 3,
        stale_text              => "some stuff",
        stale_threshold_seconds => "31m",
    }
);
$obj = $rs->find( { name => "CheckMemoryDup" } );
is( $obj->description,             "Dup of Check Memory" );
is( $obj->servicegroup->name,      "freshness checks" );
is( $obj->check_period->id,        2 );
is( $obj->check_attempts,          6 );
is( $obj->check_interval,          22 );
is( $obj->retry_check_interval,    2 );
is( $obj->plugin->name,            "check_nrpe" );
is( $obj->notification_options,    "n" );
is( $obj->invertresults,           1 );
is( $obj->notification_period,     undef );
is( $obj->notification_interval,   undef );
is( $obj->attribute->name,         "URL" );
is( $obj->flap_detection_enabled,  0 );
is( $obj->volatile,                2 );
is( $obj->event_handler,           "" );
is( $obj->markdown_filter,         1 );
is( $obj->oid,                     "SNMP:MIB-2:Stuff" );
is( $obj->critical_comparison,     "eq" );
is( $obj->critical_value,          "54" );
is( $obj->warning_value,           "100" );
is( $obj->warning_comparison,      ">" );
is( $obj->calculate_rate,          "per_second" );
is( $obj->label,                   "graphlabel" );
is( $obj->check_freshness,         1 );
is( $obj->freshness_type,          "set_stale" );
is( $obj->stale_state,             3 );
is( $obj->stale_text,              "some stuff" );
is( $obj->stale_threshold_seconds, "1860" );
@keywords = $obj->keywords;
is( scalar @keywords,   3 );
is( $keywords[0]->name, "allhosts" );
is( $keywords[1]->name, "bobgeldof" );
is( $keywords[2]->name, "elvispresley" );

$expected = {
    alert_from_failure     => 1,
    args                   => "",
    attribute              => { name => "URL" },
    calculate_rate         => "per_second",
    cascaded_from          => undef,
    check_attempts         => 6,
    check_freshness        => 1,
    check_interval         => 22,
    check_period           => { name => "workhours" },
    checktype              => { name => "Active Plugin" },
    critical_comparison    => "eq",
    critical_value         => "54",
    dependencies           => [],
    description            => "Dup of Check Memory",
    event_handler          => "",
    flap_detection_enabled => 0,
    freshness_type         => "set_stale",
    hosts                  => [],
    hosttemplates          => [],
    id                     => 111,
    invertresults          => 1,
    keywords               => [
        { name => "allhosts" },
        { name => "bobgeldof" },
        { name => "elvispresley" },
    ],
    label                   => "graphlabel",
    markdown_filter         => 1,
    name                    => "CheckMemoryDup",
    notification_interval   => undef,
    notification_options    => "n",
    notification_period     => undef,
    oid                     => "SNMP:MIB-2:Stuff",
    plugin                  => { name => "check_nrpe" },
    retry_check_interval    => 2,
    sensitive_arguments     => 1,
    servicegroup            => { name => "freshness checks" },
    stale_state             => 3,
    stale_text              => "some stuff",
    stale_threshold_seconds => 1860,
    stalking                => undef,
    uncommitted             => 1,
    volatile                => 2,
    warning_comparison      => ">",
    warning_value           => "100",
};
my $h = $obj->serialize_to_hash;
is_deeply( $h, $expected, "Got serialization" )
  || diag( "full dump: " . Data::Dump::dump($h) );

# Test deleting cascaded checks
$obj->update( { cascaded_from => 1 } );
$rs->find( { id => 1 } )->delete;
is( $rs->find( { id => 1 } ), undef, "Object not found anymore" );

my $validation = $rs->validation_regexp;
my $v_expected = {
    name                 => q{/^[\w\./-][\w \./-]{0,62}$/},
    checktype            => q{/^\d+$/},
    notification_options => "/^([wcurfsn])(,[wcurfs])*\$/",
};
is_deeply( $validation, $v_expected, "Validation as expected" );

# Test error scenarios - ignores unknown attributes
$_ = $rs->synchronise(
    {
        bum                 => "lovely",
        checktype           => 1,
        servicegroup        => { name => "Operations" },
        plugin              => "check_apt",
        name                => "NewChecks",
        snmp_community      => "public4",
        check_period        => { id => 2 },
        notification_period => { name => "nonworkhours" }
    }
);
isa_ok( $_, "Opsview::Schema::Servicechecks" );

eval {
    $rs->synchronise(
        {
            name         => "MoreNewChecks",
            servicegroup => { name => "operations" },
            plugin       => "check_tcp",
        }
    );
};
is( $@, "checktype: Missing\n", "No checktype specified" );

eval {
    $rs->synchronise(
        {
            name1        => "MoreNewChecks",
            checktype    => 1,
            servicegroup => { name => "operations" },
            plugin       => "check_tcp",
        }
    );
};
is( $@, "name: Missing\n", "No name specified" );

eval {
    $rs->synchronise(
        {
            name      => "MoreNewChecks",
            checktype => 1,
            plugin    => "check_tcp",
        }
    );
};
is( $@, "Service group not specified\n", "Service group not specified" );

eval {
    $rs->synchronise(
        {
            name         => "MoreNewChecks",
            checktype    => 1,
            servicegroup => { name => "NotExists" },
            plugin       => "check_tcp",
        }
    );
};
is(
    $@,
    "No related object for servicegroup 'name=NotExists'; Service group not specified\n",
    "Service group not found"
);

eval {
    $rs->synchronise(
        {
            name                => "MoreNewChecks",
            checktype           => 1,
            check_period        => { name => "invalid" },
            notification_period => { name => "BOB" },
            servicegroup        => { name => "Operations" },
            plugin              => "check_tcp",
        }
    );
};
is(
    $@,
    "No related object for check_period 'name=invalid'; No related object for notification_period 'name=BOB'\n",
    "check period foreign key check"
);

eval {
    $rs->synchronise(
        {
            name         => "NewChecks",
            checktype    => 1,
            dependencies => [ { name => "invalid" } ],
            plugin       => "check_tcp",
        }
    );
};
is(
    $@,
    "No related object for dependencies 'name=invalid'\n",
    "dependencies foreign key check"
);

eval {
    $rs->synchronise(
        {
            name         => "NewCheck",
            checktype    => 'active',
            servicegroup => { name => "Operations" },
            plugin       => "check_apt"
        }
    );
};
is(
    $@,
    "No related object for checktype 'active'\n",
    "dependencies foreign key check"
);

eval {
    $rs->synchronise(
        {
            name         => "bad::name",
            checktype    => 1,
            servicegroup => 1,
            plugin       => "check_tcp",
        }
    );
};
is( $@, "name: Invalid\n" );

eval {
    $rs->synchronise(
        {
            name         => " space at front",
            checktype    => 1,
            servicegroup => 1,
            plugin       => "check_tcp",
        }
    );
};
is( $@, "name: Invalid\n", "No space allowed at front" );

eval {
    $rs->synchronise(
        {
            name =>
              "1234567890123456789012345678901234567890123456789012345678901234",
            checktype    => 1,
            servicegroup => 1,
            plugin       => "check_tcp",
        }
    );
};
is( $@, "name: Invalid\n", "name too long" );

eval {
    $rs->synchronise(
        {
            name =>
              "123456789012345678901234567890123456789012345678901234567890123",
            checktype    => 1,
            servicegroup => 1,
            plugin       => "check_tcp",
        }
    );
};
is( $@, '', "name just right" );

eval {
    $rs->synchronise(
        {
            name      => "NewChecks",
            checktype => 1,
            keywords  => [ { id => 444 } ],
            plugin    => "check_tcp",
        }
    );
};
is( $@, "keywords: name: Missing\n", "Missing keyword information" );

eval {
    $rs->synchronise(
        {
            name                 => "NewChecks",
            checktype            => 1,
            notification_options => "tonnie",
            plugin               => "check_tcp",
        }
    );
};
is( $@, "notification_options: Invalid\n" );

eval {
    $rs->synchronise(
        {
            name                    => "NewChecks",
            checktype               => 1,
            stale_threshold_seconds => "tonnie",
            plugin                  => "check_tcp",
        }
    );
};
like( $@,
    qr/^DBIx::Class::Schema::txn_do\(\): Error with jira duration input for stale_threshold_seconds: tonnie/
);

eval {
    $rs->synchronise(
        {
            name         => "NotCreated",
            checktype    => 1,
            servicegroup => 1,
        }
    );
};
is( $@, "Plugin not specified\n", "Error due to no plugin specified" );

eval {
    $rs->synchronise(
        {
            name         => "NotCreated",
            servicegroup => 1,
            checktype    => 1
        }
    );
};
is(
    $@,
    "Plugin not specified\n",
    "Error due to no plugin specified for active check"
);

eval {
    $rs->synchronise(
        {
            name         => "NotCreated",
            servicegroup => 1,
            checktype    => undef
        }
    );
};
is(
    $@,
    "Plugin not specified\n",
    "Error due to no plugin specified for check type undef"
);

$obj = $rs->synchronise(
    {
        name         => "PassiveCreated",
        servicegroup => 1,
        checktype    => 2
    }
);
is( $obj->name, "PassiveCreated",
    "Can create servicecheck object here with no plugin"
);

$obj = $rs->synchronise(
    {
        name         => "/",
        checktype    => 1,
        servicegroup => 1,
        plugin       => "check_tcp",
    }
);
is( $obj->name, "/", "slash in front of name is okay" );

1;
