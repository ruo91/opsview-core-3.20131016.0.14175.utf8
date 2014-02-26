#!/usr/bin/perl

use Test::More tests => 43;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test qw(opsview);
use Opsview;
use Opsview::Hosttemplate;

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

my $expected;

my $hosttemplate = Opsview::Hosttemplate->retrieve(1);
isa_ok( $hosttemplate, "Opsview::Hosttemplate" );
@_ = $hosttemplate->managementurls;
is( $_[0]->name, "SSH",                    "Got name" );
is( $_[0]->url,  'ssh://$HOSTADDRESS$',    "Got url" );
is( $_[1]->name, "Telnet",                 "Got name" );
is( $_[1]->url,  'telnet://$HOSTADDRESS$', "Got url" );

# This host has hosttemplate 1
my $host = Opsview::Host->retrieve(4);
$_        = $host->list_managementurls;
$expected = [
    {
        name          => "SSH",
        url           => "ssh://monitored_by_slave",
        host_template => 'Base Unix',
    },
    {
        name          => "Telnet",
        url           => "telnet://monitored_by_slave",
        host_template => 'Base Unix',
    }
];
is_deeply( $_, $expected, "Got URLs expected" );

$hosttemplate = Opsview::Hosttemplate->retrieve(2);
@_            = $hosttemplate->managementurls;
is( $_[0]->name, "Web admin", "Got name" );
is( $_[0]->url, 'http://$HOSTADDRESS$:8080', "Got url" );

# This host has two host templates
$host     = Opsview::Host->retrieve(12);
$_        = $host->list_managementurls;
$expected = [
    {
        name          => "SSH",
        url           => "ssh://toclone",
        host_template => 'Base Unix',
    },
    {
        name          => "Telnet",
        url           => "telnet://toclone",
        host_template => 'Base Unix',
    },
    {
        name          => "Web admin",
        url           => "http://toclone:8080",
        host_template => 'Network - Base',
    }
];
is_deeply( $_, $expected, "Got URLs expected for multiple URLs" );

# Change order of host templates
@_ = $host->hosttemplates;
$host->set_hosttemplates_to( $_[1], $_[0] );
$_        = $host->list_managementurls;
$expected = [
    {
        name          => "Web admin",
        url           => "http://toclone:8080",
        host_template => 'Network - Base',
    },
    {
        name          => "SSH",
        url           => "ssh://toclone",
        host_template => 'Base Unix',
    },
    {
        name          => "Telnet",
        url           => "telnet://toclone",
        host_template => 'Base Unix',
    }
];
is_deeply( $_, $expected, "Got URLs expected for multiple URLs" );

$host = Opsview::Host->retrieve(1);
$_    = $host->list_managementurls;
is_deeply( $_, [], "Got blank list of URLs as not defined" );

# Creation
$hosttemplate = Opsview::Hosttemplate->create(
    {
        name           => "Base Opsview",
        description    => "Opsview system",
        managementurls => [
            {
                name => "ftp",
                url  => 'ftp://$HOSTADDRESS$',
            },
            {
                name => "vnc",
                url  => 'vnc://$HOSTADDRESS$:9001',
            }
        ],
    }
);
is( $hosttemplate->name,        "Base Opsview",   "Create name" );
is( $hosttemplate->description, "Opsview system", "Create description" );
@_ = $hosttemplate->managementurls;
is( $_[0]->name,     "ftp",                      "Management url for ftp" );
is( $_[0]->url,      'ftp://$HOSTADDRESS$',      "Got url" );
is( $_[0]->priority, 1,                          "Got priority" );
is( $_[1]->name,     "vnc",                      "Management url for vnc" );
is( $_[1]->url,      'vnc://$HOSTADDRESS$:9001', "Got url" );
is( $_[1]->priority, 2,                          "Got priority" );
my $htid = $hosttemplate->id;

# Update
$hosttemplate->update(
    {
        name           => "Base Opsview update",
        description    => "Opsview system update",
        managementurls => [
            {
                name => "rsh",
                url  => 'rsh://$HOSTADDRESS$',
            },
            {
                name => "Webmin",
                url  => 'http://$HOSTADDRESS$:8081',
            }
        ],
    }
);
is( $hosttemplate->id, $htid, "Same hosttemplate after update" );
is( $hosttemplate->name, "Base Opsview update", "Update name" );
is( $hosttemplate->description, "Opsview system update", "Update description"
);
@_ = $hosttemplate->managementurls;
is( $_[0]->name,     "rsh",                       "Management url updated" );
is( $_[0]->url,      'rsh://$HOSTADDRESS$',       "Got url" );
is( $_[0]->priority, 1,                           "Got priority" );
is( $_[1]->name,     "Webmin",                    "Management url updated" );
is( $_[1]->url,      'http://$HOSTADDRESS$:8081', "Got url" );
is( $_[1]->priority, 2,                           "Got priority" );

# Bad creation because url is bad
$hosttemplate = undef;
eval {
    $hosttemplate = Opsview::Hosttemplate->create(
        {
            name           => "Base Opsview2",
            description    => "Opsview system",
            managementurls => [
                {
                    name => "ftp",
                    url  => 'ftp $HOSTADDRESS$',
                },
                {
                    name => "vnc",
                    url  => 'vnc $HOSTADDRESS$:9001',
                }
            ],
        }
    );
};
is( $hosttemplate, undef, "Host template not created" );
like(
    $@,
    "/Opsview::Hosttemplatemanagementurl url fails 'regexp'/",
    "Got correct error"
);

# Change order of managementurls
$hosttemplate = Opsview::Hosttemplate->retrieve(1);
@_            = $hosttemplate->managementurls;
$_[0]->priority(3);
$_[0]->update;
@_ = $hosttemplate->managementurls;
is( $_[1]->name, "SSH", "Got name with new priority ordering" );
is( $_[1]->url,  'ssh://$HOSTADDRESS$',    "Got url" );
is( $_[0]->name, "Telnet",                 "Got name" );
is( $_[0]->url,  'telnet://$HOSTADDRESS$', "Got url" );

# Remove hosttemplate
$hosttemplate->delete;
$hosttemplate = Opsview::Hosttemplate->retrieve(1);
is( $hosttemplate, undef, "Host template removed" );

# bad creation because name is empty
$hosttemplate = undef;
eval {
    $hosttemplate = Opsview::Hosttemplate->create(
        {
            name           => "Base Opsview2",
            description    => "Opsview system",
            managementurls => [ { url => 'vnc://$HOSTADDRESS$:9001', } ],
        }
    );
};

is( $hosttemplate, undef, "Host template not created" );
like(
    $@,
    "/Must specify a name to create a new hostgroup/",
    "Got correct error"
);

# bad creation because name is empty
$hosttemplate = undef;
eval {
    $hosttemplate = Opsview::Hosttemplate->create(
        {
            name           => "Base Opsview2",
            description    => "Opsview system",
            managementurls => [
                {
                    name => "",
                    url  => 'telnet://$HOSTADDRESS$',
                }
            ],
        }
    );
};

is( $hosttemplate, undef, "Host template not created" );
like(
    $@,
    "/Opsview::Hosttemplatemanagementurl name fails 'regexp'/",
    "Got correct error"
);

# bad creation because name is empty
$hosttemplate = undef;
eval {
    $hosttemplate = Opsview::Hosttemplate->create(
        {
            name           => "Base Opsview2",
            description    => "Opsview system",
            managementurls => [
                {
                    name => " 	 	 	",
                    url  => 'vnc://$HOSTADDRESS$:9001',
                }
            ],
        }
    );
};

is( $hosttemplate, undef, "Host template not created" );
like(
    $@,
    "/Opsview::Hosttemplatemanagementurl name fails 'regexp'/",
    "Got correct error"
);

# Check ordered hosts
$hosttemplate = Opsview::Hosttemplate->retrieve(4);
my @hosts = $hosttemplate->ordered_hosts;
my @hostnames = map { $_->name } @hosts;
$expected = [qw(cisco3 monitored_by_cluster monitored_by_slave opsview)];
is_deeply( \@hostnames, $expected, "Got hostnames in order" );
