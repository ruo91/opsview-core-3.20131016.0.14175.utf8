#!/usr/bin/perl
# Tests for Opsview::Schema::Keywords

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);
use utf8;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Keywords" );

eval { $rs->synchronise( { name => "With spaces" } ) };
is( $@, "name: Invalid\n", "Cannot create keyword as invalid characters" );

eval { $rs->synchronise( { name => "With,comma" } ) };
is( $@, "name: Invalid\n", "Cannot create keyword as invalid comma" );

my $keyword = $rs->find(1);
is( $keyword->name, "cloneable" );

$rs      = $schema->resultset("Keywords")->retrieve_all;
$keyword = $rs->first;
is( $keyword->name, "allhandled", "Check is ordered response" );
is( $keyword->id,   9 );
is( $rs->count,     9,            "Got total of 9 keywords" );

$keyword = $schema->resultset("Keywords")->find( { name => "alphaearly" } );
my @roles = $keyword->roles;
is( scalar @roles, 2, "Got all roles" );
is( $roles[0]->name, "View some, change none" );
is( $roles[1]->name, "View some, change none - viewsomechangenone" );

my @keywords = $schema->resultset("Keywords")->search(
    { "keywordroles.keywordid" => { "!=" => undef } },
    {
        join     => "keywordroles",
        distinct => 1,
    }
);
is( scalar @keywords, 7, "Only 7 keywords with roles associated" );
my @names = map { $_->name } @keywords;
is_deeply(
    \@names,
    [
        qw(allhosts allservicechecks alphaearly cisco cisco_gp2 cloneable disabled)
    ]
) || diag( Data::Dump::dump( \@names ) );

# Check that view some, change none, no notify role can see cisco keyword, but not allhandled
is(
    $schema->resultset("Keywords")->search(
        {
            name                  => "cisco",
            "keywordroles.roleid" => 15
        },
        { join => "keywordroles" }
      )->count,
    1,
    "Have got cisco keyword in viewkeywords role..."
);
is(
    $schema->resultset("Keywords")->search(
        {
            name                  => "allhandled",
            "keywordroles.roleid" => 15
        },
        { join => "keywordroles" }
      )->count,
    0,
    "...but not allhandled"
);

$keyword = $schema->resultset("Keywords")->find( { name => "cisco" } );
my @hosts = $keyword->hosts;
is( scalar @hosts,                5,       "5 hosts for cisco keyword" );
is( $keyword->hosts->count,       5,       "5 hosts for cisco keyword" );
is( $keyword->hosts->first->name, "cisco", "Getting host name" );

is(
    $keyword->servicechecks->count,
    4, "With 4 service checks for cisco keyword"
);
is(
    $keyword->servicechecks->first->name,
    "Another exception",
    "Getting service check name (sorted alphabetically)"
);

my $viewkeywords =
  $schema->resultset("Roles")->find( { name => "View some, change none" } );
is( $viewkeywords->name, "View some, change none" );
is(
    $viewkeywords->contacts->first->name,
    "viewkeywords", "viewkeywords contact is included"
);

@keywords = $viewkeywords->access_keywords;
my @keyword_names = map { $_->name } @keywords;
my @expected = qw(alphaearly cisco);
is_deeply( \@keyword_names, \@expected, "Same names" );

my $readonly =
  $schema->resultset("Roles")->find( { name => "View all, change none" } );

@names = map { $_->name } $readonly->valid_hostgroups;
@expected = (
    "alphaearly",         "Leaf",
    "Leaf2",              "middling",
    "Monitoring Servers", 'Passive Monitoring',
    "singlehost"
);
is_deeply( \@names, \@expected, "Order of hostgroups" );

@names = map { $_->name } $readonly->valid_servicegroups;
@expected = ( "freshness checks", "Operations" );
is_deeply( \@names, \@expected, "Order of servicegroups" );

my $uncommitted_flag = $schema->resultset("Metadata")->find( "uncommitted" );
$uncommitted_flag->update( { value => 0 } );
is( $uncommitted_flag->value, 0, "Uncommitted" );

my $k = $rs->synchronise(
    {
        name          => "newobjects",
        hosts         => [ { id => 7 }, { name => "cisco3" } ],
        servicechecks => [ { id => 47 }, { name => "Test exceptions" } ],
        roles         => [ { id => 10 }, { name => "View some, change none" } ],
    }
);
isa_ok( $k, "Opsview::Schema::Keywords" );
is( $k->name, "newobjects" );
@names = map { $_->name } $k->hosts;
is_deeply( \@names, [qw(cisco cisco3)], "Got hosts" );
@names = map { $_->name } $k->servicechecks;
is_deeply( \@names, [ "/", "Test exceptions" ], "Got service checks" );
@names = map { $_->name } $k->roles;
is_deeply( \@names, [ "Admin", "View some, change none" ], "Got roles" );
is( $k->all_hosts,         0, "Default to 0 for all_hosts" );
is( $k->all_servicechecks, 0, "Default to 0 for all_servicechecks" );
is( $k->uncommitted,       1, "Uncommitted flag set" );
is(
    $schema->resultset("Metadata")->find("uncommitted")->value,
    1, "And set centrally"
);

# We're also doing a test here to confirm that the all_keyword flag does not affect the use of keywords in the notification profiles

# Create a notification profile for admin user
$schema->resultset("Contacts")->synchronise(
    {
        name                 => "admin",
        notificationprofiles => [
            {
                name                => "roleallkeywordtest",
                all_keywords        => 0,
                keywords            => [ { name => "newobjects" } ],
                notificationmethods => [ { name => "Email" } ]
            }
        ]
    }
);

# Set this user's role to have all_keywords
$schema->resultset("Roles")->synchronise(
    {
        name         => "Admin",
        all_keywords => 1
    }
);

# Edit the keyword to remove all roles
$k = $rs->synchronise(
    {
        name              => "newobjects",
        hosts             => [],
        all_hosts         => 1,
        servicechecks     => [],
        roles             => [],
        all_servicechecks => 1,
    }
);
is( $k->all_hosts,            1 );
is( $k->all_servicechecks,    1 );
is( $k->hosts->count,         0 );
is( $k->servicechecks->count, 0 );
is( $k->roles->count,         0 );

# Check that the notification profile still lists the keywords
my @notificationprofiles;
@notificationprofiles =
  $schema->resultset("Contacts")->find( { name => "admin" } )
  ->notificationprofiles;
is(
    scalar @notificationprofiles,
    1, "Only one notification profile for admin user"
);
is( $notificationprofiles[0]->name,         "roleallkeywordtest" );
is( $notificationprofiles[0]->all_keywords, 0 );
is(
    $notificationprofiles[0]->keywords->count,
    1, "Should still have the one keyword"
);
is( $notificationprofiles[0]->keywords->first->name, "newobjects" );

@notificationprofiles =
  $schema->resultset("Contacts")->find( { name => "viewkeywords" } )
  ->notificationprofiles;
is( $notificationprofiles[0]->name,                  "High priority" );
is( $notificationprofiles[0]->keywords->first->name, "cisco" );
is( $notificationprofiles[1]->name,                  "Default" );
is(
    $notificationprofiles[1]->keywords->count,
    0, "This is zero because all_keywords is set..."
);
is( $notificationprofiles[1]->all_keywords,          1, "...see?" );
is( $notificationprofiles[1]->valid_keywords->count, 2, "But get two here" );

$k = $rs->synchronise(
    {
        name  => "cisco",
        roles => [],
    }
);
is(
    $notificationprofiles[0]->keywords->first,
    undef, "Keyword removed from notification profiles"
);
is(
    $notificationprofiles[1]->valid_keywords->count,
    1, "Other profile also has lost that keyword as removed from role"
);
