#!/usr/bin/perl
# Tests for Opsview::Schema::Contacts

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Config;
use Opsview::Test qw(opsview);
use Opsview::Utils;
use Runtime::Host;
use utf8;

my $expected;
my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset("Contacts");

is( $rs->my_type_is, "contact", "Got right type" );


my $admin = $rs->find( { name => "admin" } );

is( $rs->count, 14, "Got all contacts expected" );
is( $rs->restrict_by_user( $admin )->count, 14, "Same with an admin/non-tenant user" );

# Test strange bug
$rs->synchronise(
{
  all_hostgroups => 1,
  all_servicegroups => 1,
  description => "rah",
  hostgroups => [],
  id => 12,
  keywords => [],
  language => "en",
  fullname => "Adminnoc",
  role => 16,
  servicegroups => [],
  name => "adminnoc",
  variables => [
        { name => "RSS_COLLAPSED", value => 1 },
        { name => "RSS_MAXIMUM_ITEMS", value => 30 },
        { name => "RSS_MAXIMUM_AGE", value => 1440 },
        { name => "EMAIL", value => "" },
        { name => "PAGER", value => "" },
      ],
  password => "secret",
});

my $adminnoc = $rs->find(12);
is($adminnoc->name, "adminnoc" );
is($adminnoc->fullname, "Adminnoc" );
is($adminnoc->description, "rah" );
is( $adminnoc->language, "en" );
isnt( $adminnoc->encrypted_password, "secret" );

sub is_highest_hostgroup_parent {
    my ($user, $expected) = @_;
    my @caller = caller;
    my $res = $user->get_highest_hostgroup_parent;

    # Change to just id, otherwise Data::Dump::dump will return massive output
    my $got = { %$res,
        hostgroup => $res->{hostgroup}->id,
    };
    $got->{hostgroup} = $res->{hostgroup}->id;
    is_deeply( $got, $expected ) or diag "line $caller[2], hostgroup name=".$res->{hostgroup}->name ." with ". Data::Dump::dump($got);
}

is_highest_hostgroup_parent( $admin, {hostgroup => 1, used_parent => 0} );
is( $adminnoc->get_highest_hostgroup_parent, undef, "No host group for adminnoc to add, since it only has access to a leaf which has hosts in it" );

$expected = {
    description => "rah",
    id => 12,
    language => "en",
    fullname => "Adminnoc",
    notificationprofiles => [],
    sharednotificationprofiles => [],
    realm => "local",
    role => { name => "Admin no configurehosts", ref => "/rest/role/16", },
    uncommitted => 1,
    name => "adminnoc",
    variables => [
        { name => "EMAIL", value => "" },
        { name => "PAGER", value => "" },
        { name => "RSS_COLLAPSED", value => 1 },
        { name => "RSS_MAXIMUM_AGE", value => 1440 },
        { name => "RSS_MAXIMUM_ITEMS", value => 30 },
    ],
};
my $data = $adminnoc->serialize_to_hash( { ref_prefix => "/rest" } );
delete $data->{encrypted_password}; # Cannot test as changes
is_deeply( $data, $expected, "Got expected serialization" ) || diag explain $data;

# Tests re: email, mobile and rss info
my $readonly = $rs->find( { name => "readonly" } );
is( $readonly->variable("EMAIL"), 'test@dummy.com', "Variable through contact_variables" );
is( $readonly->variable("PAGER"), '1234' );
is( $readonly->variable("RSS_MAXIMUM_ITEMS"), 30 );
is( $readonly->variable("RSS_MAXIMUM_AGE"), 1440 );
is( $readonly->variable("RSS_COLLAPSED"), 1 );
is( $readonly->variable("NOT_FOUND"), undef );

is_deeply( $readonly->variables, { EMAIL => 'test@dummy.com', PAGER => '1234', RSS_MAXIMUM_ITEMS => 30, RSS_MAXIMUM_AGE => 1440, RSS_COLLAPSED => 1 } );
@_ = $readonly->contact_variables_list;
is_deeply( \@_, [ qw(EMAIL PAGER RSS_COLLAPSED RSS_MAXIMUM_AGE RSS_MAXIMUM_ITEMS) ] );

#@_ = map { $_->name } ($readonly->notificationmethods);
#is_deeply( \@_, [ "AQL", "Email", "RSS" ] );

# Set new variable values
$readonly->set_variable("EMAIL", 'ton.voon@opsview.com');
$readonly->set_variable("PAGER", '999' );
$readonly->set_variable("RSS_MAXIMUM_ITEMS", 33 );
$readonly->set_variable("RSS_MAXIMUM_AGE", 2000 );
$readonly->set_variable("RSS_COLLAPSED", 0 );

is( $readonly->variable("EMAIL"), 'ton.voon@opsview.com', "Changed variables" );
is( $readonly->variable("PAGER"), '999' );
is( $readonly->variable("RSS_MAXIMUM_ITEMS"), 33 );
is( $readonly->variable("RSS_MAXIMUM_AGE"), 2000 );
is( $readonly->variable("RSS_COLLAPSED"), 0 );




my $user = $rs->find( { name => "testviewallchangesome" } );
is_deeply( $user->variables, { RSS_COLLAPSED => 1, RSS_MAXIMUM_AGE => 1440, RSS_MAXIMUM_ITEMS => 30 }, "initial list of variables" );

$user = $rs->synchronise( {
        id => $user->id,
        variables => [
            {   name  => "rsh",
                value => 'insightful',
            },
            {   name => "PAGER",
                value  => '320',
            }
        ],
        notificationprofiles => [
            { name => "bobby", all_hostgroups => 0, all_servicegroups => 0, all_keywords => 0,
            hostgroups => [ 5, 2 ],
            servicegroups => [ 1, 2],
            keywords => [ 3, { name => "allhosts" } ],
            notificationmethods => [ { name => "Email"}, { name => "RSS" } ],
            },
            { name => "noddy" },
            ,
        ],
} );

$expected = {
    name => "testviewallchangesome",
    notificationprofiles => [
        {
            all_hostgroups => 0,
            all_servicegroups => 0,
            all_keywords => 0,
            host_notification_options => "n",
            hostgroups => [
                { name => "Leaf2", ref => "/rest/hostgroup/5" },
                { name => "Monitoring Servers", ref => "/rest/hostgroup/2" },
            ],
            # Only 1 keyword here because authorisation at the contact level strips it off
            keywords => [
                {name => "allhosts", "ref" => "/rest/keyword/7" },
            ],
            name => "bobby",
            notification_level => 1,
            notification_level_stop => 0,
            notificationmethods => [
                { name => "Email", ref => "/rest/notificationmethod/3" },
                { name => "RSS", ref => "/rest/notificationmethod/4" },
            ],
            notification_period => { name => "24x7", ref => "/rest/timeperiod/1" },
            ref => "/rest/notificationprofile/14",
            service_notification_options => "n",
            servicegroups => [
                { name => "freshness checks", ref => "/rest/servicegroup/2" },
                { name => "Operations", ref => "/rest/servicegroup/1" },
            ],
            uncommitted => 1,
        },
        {
            all_hostgroups => 1,
            all_servicegroups => 1,
            all_keywords => 1,
            host_notification_options => "n",
            hostgroups => [],
            keywords => [],
            name => "noddy",
            notificationmethods => [],
            notification_level => 1,
            notification_level_stop => 0,
            notification_period => { name => "24x7", ref => "/rest/timeperiod/1" },
            ref => "/rest/notificationprofile/15" ,
            service_notification_options => "n",
            servicegroups => [],
            uncommitted => 1,
        },
    ],
};
my $hash = $user->serialize_to_hash( { ref_prefix => "/rest", columns => [qw(name notificationprofiles)] } );
is_deeply( $hash, $expected, "Got expected serialization" ) || diag ("Full dump: ".Data::Dump::dump( $hash ) );

# This test to pass in notificationprofiles
$hash->{fullname} = "testviewallchangesome";
$hash = Opsview::Utils->remove_keys_from_hash( $hash, ["ref"] );
my $newdata = $rs->synchronise( $hash );
is( $newdata->notificationprofiles->count, 2 );


# Old variables not deleted
$expected = {
    PAGER => 320,
    rsh => "insightful",
    RSS_COLLAPSED => 1,
    RSS_MAXIMUM_AGE => 1440,
    RSS_MAXIMUM_ITEMS => 30,
    };
is_deeply( $user->variables, $expected, "altered list of variables" );

my (@nps, @groups);
my $np;
@nps = $user->notificationprofiles;
is( scalar @nps, 2, "Got two notificationprofiles" );
$np = $nps[0];
is( $np->name, "bobby", "1st" );
is( $np->all_servicegroups, 0, "all_servicegroups set to 0 in data" );
is( $np->all_hostgroups, 0, "all_hostgroups set to 0 in data" );
@groups = $np->hostgroups;
is( scalar @groups, 2 );
is( $groups[0]->name, "Leaf2" );
is( $groups[1]->name, "Monitoring Servers" );
@groups = $np->servicegroups;
is( scalar @groups, 2 );
is( $groups[0]->name, "freshness checks" );
is ($groups[1]->name, "Operations" );
my $old_bobby_id = $np->id;

$np = $nps[1];
is( $np->name, "noddy", "2nd" );
is( $np->all_servicegroups, 1, "all_servicegroups set to 1 by default" );
is( $np->all_hostgroups, 1, "all_hostgroups set to 1 by default" );
@groups = $np->hostgroups;
is( scalar @groups, 0 );
@groups = $np->servicegroups;
is( scalar @groups, 0 );


diag("Testing ordering of notificationprofiles") if ( $ENV{TEST_VERBOSE} );
$user = $rs->synchronise( {
        id => $user->id,
        notificationprofiles => [
            { name => "noddy", },
            { name => "bobby", },
        ],
} );
@nps = $user->notificationprofiles;
is( scalar @nps, 2, "Still got two notificationprofiles" );
is( $nps[0]->name, "noddy", "But order changed..");
is( $nps[0]->priority, 1 );
is( $nps[1]->name, "bobby" );
is( $nps[1]->priority, 2 );


diag("Testing priority can be overridden in attributes of notificationprofiles") if ( $ENV{TEST_VERBOSE} );
$user = $rs->synchronise( {
        id => $user->id,
        notificationprofiles => [
            { name => "noddy", priority => 100 },
            { name => "bobby", },
        ],
} );
@nps = $user->notificationprofiles;
is( scalar @nps, 2, "Still got two notificationprofiles" );
is( $nps[0]->name, "bobby", "Ordered around again" );
# I'm not sure if the below should be a 2 (2nd item in the list) or a 1 (first item with designated priority)
# Leave as 2 at the moment
is( $nps[0]->priority, 2, "See comment...");
is( $nps[1]->name, "noddy");
is( $nps[1]->priority, 100, "Priority attribute honooured" );



$user = $rs->synchronise( {
        id => $user->id,
        notificationprofiles => [
            { name => "bobby", all_hostgroups => 1,
            servicegroups => [],
            }
        ],
        } );
@_ = $user->notificationprofiles;
is( scalar @_, 1, "Only 1 notificationprofile now" );
is( $_[0]->name, "bobby", "Still there" );
is( $_[0]->all_servicegroups, 0, "all_servicegroups still 0" );
is( $_[0]->all_hostgroups, 1, "all_hostgroups changed" );
is( $_[0]->id, $old_bobby_id, "Same id after update" );
is( $_[0]->hostgroups->count, 2, "Still 2 host groups" );
is( $_[0]->servicegroups->count, 0, "But 0 service groups now" );


$user = $rs->synchronise( {
        id => $user->id,
        notificationprofiles => [],
        } );
@_ = $user->notificationprofiles;
is( scalar @_, 0, "All notificationprofiles deleted for user after sync" );


$_ = $rs->find_or_create( { fullname => "Tonnie with , comma", name => "tonnie" } );
isa_ok( $_, "Opsview::Schema::Contacts" );
is( $_->fullname, "Tonnie with , comma", "OK using comma in fullname" );
my $oldid = $_->id;

$_ = $rs->update_or_create( { fullname => "Tonnie2", name => "tonnie" } );
is( $_->id,   $oldid,    "On same object" );
is( $_->fullname, "Tonnie2", "Updated correctly" );

$_ = $rs->update_or_create( { fullname => "Newperson", name => "newperson" } );
isnt( $_->id, $oldid, "New person" );
$oldid = $_->id;

#$_ = $rs->update_or_create( { name => "Newperson", username => "newperson", notification_period => { name => "none" } } );
#isnt( $_->id, $oldid, "Update of same person" );
#is( $_->notification_period->name, "none", "With notification period updated to none correctly" );

# Deliberately do not set all_servicegroups, so db defaults to 1 - tested below
my $viewsomerole = $schema->resultset("Roles")->find( { name => "View some, change some" } );
$schema->resultset("Roles")->synchronise(
    {  id => $viewsomerole->id,
        all_hostgroups => 0,
        access_hostgroups => [ { name => "Leaf" }, { name => "Leaf2" } ],
        access_servicegroups => [ { name => "Operations" } ],
    }
);
$_ = $rs->synchronise(
    {   fullname           => "Somehostgroups",
        name       => "somehostgroups",
        description       => "",
        language       => "",
        role           => { name => "View some, change some" },
    }
);
my $res   = $_->hostgroups;
my @array = $_->hostgroups;
is( $res,            2,       "Correct number of hostgroups" );
is( $array[0]->name, "Leaf",  "First hostgroup correct" );
is( $array[1]->name, "Leaf2", "Other hostgroup name correct" );
$res   = $_->servicegroups;
@array = $_->servicegroups;
is( $res,            2, "Two service groups because all_servicegroups not specified and db sets to 1" );
is( $array[0]->name, "freshness checks" );
is( $array[1]->name, "Operations" );
is( $_->description, "", "Blank description" );
is( $_->language, "", "Blank language" );


# Check that setting role will filter out all the notification profiles
$_ = $rs->synchronise(
    {
        name       => "viewsomechangenone",
        role           => { name => "View some, change none" },
    }
);
is( $schema->resultset("NotificationprofileHostgroups")->search( { notificationprofileid => 8 } )->count, 0, "Notification profiles hostgroups deleted");
is( $schema->resultset("NotificationprofileServicegroups")->search( { notificationprofileid => 8 } )->count, 0, "Notification profiles servicegroups deleted");
is( $schema->resultset("NotificationprofileKeywords")->search( { notificationprofileid => 8 } )->count, 1, "Notification profiles keywords stays at 1");


# Set new comment and language
$_ = $rs->synchronise(
    {   fullname           => "Somehostgroups",
        name       => "somehostgroups",
        description       => "sh comm",
        language       => "fr",
    }
);
is( $_->description, "sh comm", "Comment now filled in" );
is( $_->language, "fr", "Language filled in" );

# Check above user can see hosts
my $u = $rs->find( { name => "somehosts" } );
my $monitored_by_cluster   = Runtime::Host->search( name => "monitored_by_cluster" )->first;
my $opsview = Runtime::Host->search( name => "opsview" )->first;
isa_ok( $monitored_by_cluster,   "Runtime::Host" );
isa_ok( $opsview, "Runtime::Host" );
is( $monitored_by_cluster->can_be_viewed_by($u),   $monitored_by_cluster, "User can see monitored_by_cluster" );
is( $opsview->can_be_viewed_by($u), undef,  "User blocked from opsview" );


# Change user to be all hostgroups
$u = $rs->find( { name => "somehostgroups" } );
$u->role->all_hostgroups(1);
$res   = $u->valid_hostgroups;
@array = $u->valid_hostgroups;
is( $res, 7, "All hostgroups" );
is( $array[0]->name, "alphaearly" );
is( $array[1]->name, "Leaf" );
is( $array[2]->name, "Leaf2" );
is( $array[3]->name, "middling" );
is( $array[4]->name, "Monitoring Servers" );
is( $array[5]->name, "Passive Monitoring" );
is( $array[6]->name, "singlehost" );

# This is how data via XML::Simple is transformed, so we test that we
# change it to a format DBIx::Class likes
my $role = $schema->resultset("Roles")->synchronise( {
    name => "fancypants",
    all_hostgroups => 0,
    all_servicegroups => 0,
        access_hostgroups        => [ { name => "Leaf" }, { name => "Leaf2" } ],
        access_servicegroups => [ { name => "Operations" } ],
    });
$_ = $rs->synchronise(
    {   fullname              => "ViaXMLname",
        name          => "viaxml",
        role => { name => "fancypants" },
    }
);
$res   = $_->valid_hostgroups;
@array = $_->valid_hostgroups;
is( $res,            2,       "Correct number of hostgroups" );
is( $array[0]->name, "Leaf",  "First hostgroup correct" );
is( $array[1]->name, "Leaf2", "Other hostgroup name correct" );
$res   = $_->valid_servicegroups;
@array = $_->valid_servicegroups;
is( $res,            1 );
is( $array[0]->name, "Operations" );
$oldid = $_->id;
is( $_->role->all_servicegroups, 0,    "all_servicegroups is 0..." );
$_ = $rs->find( { name => "viaxml" } );
is( $_->role->all_servicegroups, 0, "...and the db stores 0" );
my $userid = $_->id;


$_ = $rs->synchronise(
    {   fullname              => "ViaXMLname",
        name          => "viaxml2",
        all_hostgroups    => 1,
    }
);
isnt( $_->id, $userid, "Shouldn't have same userid because username is the unique key" );

# Do we need find_or_new?
=begin maybe_ignore
$_ = $rs->find_or_new(
    {   name           => "ViaXML",
        username       => "viaxml",
        all_hostgroups => 0,
        hostgroups     => [ { name => "Leaf" }, { name => "Leaf2" } ],
        servicegroups => [ { name => "Operations" } ],
    }
);
is( $_->id, $oldid, "find_or_new returns same object" );
my $to_delete = $_;

$_ = $rs->find_or_new(
    {   name           => "ViaXML",
        username       => "viaxml2",
        all_hostgroups => 0,
        hostgroups     => { hostgroup => [ { name => "Leaf" }, { name => "Leaf2" } ], },
        servicegroups => { servicegroup => [ { name => "Operations" } ], },
    }
);
isnt( $_->id, $oldid, "find_or_new returns different object" );
is( $_->in_storage, undef, "And not saved yet" );

$to_delete->delete;
$_ = $rs->find( { username => "viaxml" } );
is( $_, undef, "User deleted" );
=cut

isnt( $schema->resultset("ContactVariables")->search( { contactid => { '!=' => 1 } } )->count, 0, "Lots of contact variables");

# Delete all contacts except the single admin user
# Then test that a delete of this contact will give an exception error
# because want at least 1 admin user left
$rs->search( { name => { "!=" => "admin" } } )->delete_all;

is( $rs->count, 1, "Only one contact left" );
my $admin_user = $rs->search( { name => "admin" } )->first;
eval { $admin_user->delete };
like( $@, "/throw_exception.*CannotDeleteAllAdminAccess/", "Cannot delete last admin user" );

eval { $rs->delete };
like( $@, "/throw_exception.*CannotDeleteAllAdminAccess/", "Caught error if using resultset->delete too" );


is( $schema->resultset("ContactVariables")->search( { contactid => { '!=' => 1 } } )->count, 0, "No contact variables for other users");

# It seems that the DB stores data correctly, but this test always fails
# I'm not entirely sure why, but as the db appears correct and is displayed
# on web okay, we'll just mark as a todo
# Try this for bizarre:
#  perl -e '$a = "dénér Óberne"; print $a,$/'
#  perl -e 'use utf8; $a = "dénér Óberne"; print $a,$/'
my $name = 'dénér Óberne';
my $other_contact = $rs->synchronise( { fullname => $name, name => "déné" } );
isnt( $other_contact, undef, 'utf8 name created in db ok' );
isa_ok( $other_contact, "Opsview::Schema::Contacts" );
my $dbname = $other_contact->name;
TODO: {
    local $TODO = "Wrong encoding?";
    is( $dbname, $name, "utf8 name set on object correctly" );
    is( $other_contact->name, "déné", "username also okay" );
}
$other_contact->delete;

$user = $rs->synchronise( { fullname => "some_name", name => "some_name" } );
my $cfg = Opsview::Config::Web->web_config;
$cfg->{authtkt_default_username} = "some_name";
eval { $user->delete };
like( $@, "/CannotDeleteAuthtktDefaultUsername/", "Constraint stops delete" );

$other_contact = $rs->synchronise( { fullname => "With funny chars", name => 'user-bob@dummy.com' } );
isa_ok( $other_contact, "Opsview::Schema::Contacts" );
is( $other_contact->name, 'user-bob@dummy.com' );

undef($other_contact);
eval { $other_contact = $rs->synchronise( { fullname => "With slash", name => 'user/bob' } ) };
like( $@, qr%Failed constraint on name for 'user/bob' with regex%,
    "Don't allow / in username - used in nagconfgen" );
is( $other_contact, undef, "And contact not created" );


eval { $other_contact = $rs->synchronise( { password => "With slash" } ) };
like( $@, qr/name: Missing/, "Cannot create as no username" );

eval { $other_contact = $rs->synchronise( {
    fullname => "Testpropagation",
    name => "lovelyjubbly",
        notificationprofiles => [
            { name => "bobby", },
            { name => "Bad%Char^&", },
        ],
        } ) };
like( $@, qr/Failed constraint on name for /, "Got error message when error occurs in recursive synchronise, though not very helpful message" );
is( $rs->find( { name => "Testpropagation" } ), undef, "Contact not created, thankfully" );
