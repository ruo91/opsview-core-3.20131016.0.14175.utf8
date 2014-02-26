#!/usr/bin/perl
# Tests for Opsview::ResultSet::Sharednotificationprofiles

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);
use utf8;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Sharednotificationprofiles" );

my $admin_role =
  $schema->resultset("Roles")->find( { name => "keywordonly" } );

my $temp_profile = $rs->synchronise(
    {
        role                => $admin_role->id,
        name                => "attemptedsecuritybreach",
        hostgroups          => [ 5, 2 ],
        servicegroups       => [ 1, 2 ],
        keywords            => [ 6, 1, 3 ],
        all_hostgroups      => 0,
        all_servicegroups   => 0,
        all_keywords        => 0,
        notificationmethods => [ { name => "email" }, { name => "RSS" } ],
    }
);
is( $temp_profile->hostgroups->count, 2, "Got two hostgroups" );
my @names = map { $_->name } ( $temp_profile->hostgroups );
is_deeply( \@names, [ "Leaf2", "Monitoring Servers" ], "Got host group names" )
  || diag explain \@names;
is( $temp_profile->servicegroups->count, 2, "Got two servicegroups" );
is( $temp_profile->keywords->count,      3, "Got 3 keywords" );
is( $temp_profile->all_hostgroups,       0, "Got all_hostgroups flag" );
is( $temp_profile->all_servicegroups,    0, "Got all_servicegroups flag" );
is( $temp_profile->all_keywords,         0, "Got all_keywords flag" );
is(
    $temp_profile->notificationmethods->count,
    2, "Got two notificationmethods"
);
@names = map { $_->name } ( $temp_profile->notificationmethods );
is_deeply( \@names, [ "Email", "RSS" ], "Got notificationmethod names" )
  || diag explain \@names;

__DATA__
my $nonadmin = $schema->resultset("Contacts")->find(2);
my @nps;
my $temp_profile;

@nps = $nonadmin->notificationprofiles;
is( scalar @nps, 1, "One notification profile for nonadmin user" );

$temp_profile = $rs->synchronise( { contactid => 2, name => "Newprofile" } );

@nps = $nonadmin->notificationprofiles;
is( scalar @nps, 2, "New profile created" );

my $it;
$it = $rs->search( { contactid => 2 } );
is( $it->count, 2, );

my $uncommitted_flag = $schema->resultset("Metadata")->find("uncommitted");
$uncommitted_flag->update( { value => 0 } );
is( $uncommitted_flag->value, 0, "Uncommitted" );

$temp_profile = $rs->synchronise( { contactid => 2, name => "Newprofile" } );
is( $schema->resultset("Metadata")->find("uncommitted")->value, 1, "Committed" );
@nps = $nonadmin->notificationprofiles;
is( scalar @nps, 2, "No new profile created (unique key)" );
my $oldid = $temp_profile->id;

is( $temp_profile->uncommitted, 1 );
system("/usr/local/nagios/bin/reset_uncommitted");
$temp_profile->discard_changes;
is( $temp_profile->uncommitted, 0 );

$temp_profile = $rs->synchronise( { id => $oldid, contactid => 2, name => "Newprofile" } );
@nps = $nonadmin->notificationprofiles;
is( scalar @nps, 2, "No new profile created, because old id used" );

is( $temp_profile->host_notification_options,    "n", "Got an 'n' when no host options set" );
is( $temp_profile->service_notification_options, "n", "Got an 'n' when no service options set" );

my ( @hgids, @sgids, @keyids );

my $restricted = $schema->resultset("Contacts")->find( { name => "viewsomechangenone" } );
is( $restricted->notificationprofiles->count, 1, "Only 1 notification profile" );

$temp_profile = $rs->synchronise(
    {   contactid         => $restricted->id,
        name              => "attemptedsecuritybreach",
        hostgroups        => [ 5, 2 ],
        servicegroups     => [ 1, 2 ],
        keywords          => [ 6, 1, 3 ],
        all_hostgroups    => 0,
        all_servicegroups => 0,
    }
);
is( $restricted->notificationprofiles->count, 2, "New notification profile created" );

# This is also testing that you get an array back in an array context,
# and a scalar back in a scalar context
@hgids  = map { $_->id } $temp_profile->valid_hostgroups->all;
@sgids  = map { $_->id } $temp_profile->valid_servicegroups;
@keyids = map { $_->id } $temp_profile->valid_keywords;
is_deeply( \@hgids,  [5] );
is_deeply( \@sgids,  [1] );
is_deeply( \@keyids, [6] );

$temp_profile->update( { all_hostgroups => 1, all_servicegroups => 1 } );
@hgids = map { $_->id } $temp_profile->valid_hostgroups;
@sgids = map { $_->id } $temp_profile->valid_servicegroups->all;
is_deeply( \@hgids, [ 4, 5 ] );
is_deeply( \@sgids, [1] );

$temp_profile->update( { all_hostgroups => 0, all_servicegroups => 0 } );
@hgids  = map { $_->id } $temp_profile->hostgroups;
@sgids  = map { $_->id } $temp_profile->servicegroups;
@keyids = map { $_->id } $temp_profile->keywords;
is_deeply( \@hgids,  [5], "Check initial values for hostgroup" );
is_deeply( \@sgids,  [1], "Ditto for servicegroups" );
is_deeply( \@keyids, [6], "And same for keywords" );

my $new_restricted = $schema->resultset("Roles")->synchronise(
    {   id                   => $restricted->role->id,
        all_hostgroups       => 0,
        all_servicegroups    => 0,
        all_keywords         => 0,
        access_hostgroups    => [4],
        access_servicegroups => [2],
        access_keywords      => [1],
    }
);
@hgids  = map { $_->id } $temp_profile->hostgroups;
@sgids  = map { $_->id } $temp_profile->servicegroups;
@keyids = map { $_->id } $temp_profile->keywords;
is_deeply( \@hgids,  [], "Other hostgroups removed due to removal from contacts" );
is_deeply( \@sgids,  [], "Ditto for servicegroups" );
is_deeply( \@keyids, [], "And same for keywords" );

$temp_profile = $rs->synchronise( { contactid => 1, name => "Adminprofile" } );
is( $temp_profile->all_hostgroups,    1, "all_hostgroups set by default" );
is( $temp_profile->all_servicegroups, 1, "all_servicegroups set by default" );
@hgids = map { $_->id } $temp_profile->valid_hostgroups->all;
is( scalar @hgids, 7, "Only show the 7 leaf host groups" );

eval { $rs->synchronise( { contactid => 1, name => "bad%%chars" } ) };
like( $@, qr/Failed constraint on name for 'bad%%chars' with regex/, "Constraints on name" );

eval { $rs->synchronise( { contactid => 1, name => "Adminprofile", host_notification_options => "fsd", service_notification_options => "blah" } ) };
is( $@, "host_notification_options: Invalid; service_notification_options: Invalid\n", "Constraints on host/service_notification_options" );

1;
