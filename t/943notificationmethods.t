#!/usr/bin/perl
# Tests for Opsview::Schema notificationmethods

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Config;
use Opsview::Test qw(opsview);
use utf8;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Notificationmethods" );

is( $rs->count, 6, "Six notification methods..." );
is( $rs->search( { active => 1 } )->count, 4, "...but only 4 active" );

my $unused = $rs->find( { name => "unused" } );
is(
    $unused->notificationprofiles->count,
    1, "One notification profile with for this method"
);
is( $unused->notificationprofiles->first->name, "Default", "Right name" );
is(
    $unused->notificationprofiles->first->contact->name,
    "nonadmin", "For nonadmin user"
);

my $expected;
$expected = [
    {
        variable            => "EMAIL",
        notificationmethods => ["Email"]
    },
    {
        variable            => "PAGER",
        notificationmethods => ["AQL"]
    },
    {
        variable            => "RSS_MAXIMUM_ITEMS",
        notificationmethods => ["RSS"]
    },
    {
        variable            => "RSS_MAXIMUM_AGE",
        notificationmethods => ["RSS"]
    },
    {
        variable            => "RSS_COLLAPSED",
        notificationmethods => ["RSS"]
    },
];
my $got = $rs->full_required_variables_list;
is_deeply( $got, $expected );

my $uncommitted_flag = $schema->resultset("Metadata")->find( "uncommitted" );
$uncommitted_flag->update( { value => 0 } );
is( $uncommitted_flag->value, 0, "Uncommitted" );

my $notificationmethod = $schema->resultset("Notificationmethods")->create(
    {
        name              => "Bobby-Ewing",
        contact_variables => "bamber,gasgoine",
        uncommitted       => 1,
    }
);
is( $notificationmethod->name,              "Bobby-Ewing" );
is( $notificationmethod->nagios_name,       "bobby-ewing" );
is( $notificationmethod->contact_variables, "BAMBER,GASGOINE" );
@_ = $notificationmethod->required_variables_list;
is_deeply( \@_, [qw(BAMBER GASGOINE)] );

undef $uncommitted_flag;
$uncommitted_flag = $schema->resultset("Metadata")->find( "uncommitted" );
is( $uncommitted_flag->value, 1, "Uncommitted flag changed" );

my $duplicate;
eval {
    $duplicate = $schema->resultset("Notificationmethods")->create(
        {
            name              => "bobby-ewing",
            contact_variables => "bamber,gasgoine",
        }
    );
};
like(
    $@,
    qr/Duplicate entry 'bobby-ewing' for key /,
    "Constraint failure due to same name"
);

eval { $notificationmethod->update( { name => "bad: name" } ) };
like( $@, qr/Failed constraint on name for /, "name constraint is triggered" );

eval { $notificationmethod->update( { contact_variables => "bad space" } ) };
like(
    $@,
    qr/Failed constraint on contact_variables for /,
    "contact variables constraint is triggered"
);

my $nm = $rs->synchronise(
    {
        name      => "okay with spaces",
        variables => [
            {
                name  => "AQL_USERNAME",
                value => 'insightful',
            },
            {
                name  => "AQL_PASSWORD",
                value => 'p4ssw0rd',
            }
        ],
    }
);
isa_ok( $nm, "Opsview::Schema::Notificationmethods" );
is( $nm->name, "okay with spaces" );
is_deeply(
    $nm->variables_hash,
    {
        AQL_USERNAME => 'insightful',
        AQL_PASSWORD => 'p4ssw0rd'
    },
    "got variables"
);
is( $nm->variable("AQL_USERNAME"), "insightful" );
is( $nm->variable("AQL_PASSWORD"), "p4ssw0rd" );
is( $nm->namespace, "okaywithspaces", "Got generated namespace" );

$nm = $rs->synchronise(
    {
        name      => "okay with spaces",
        variables => [
            {
                name  => "AQL_USERNAME",
                value => 'changed',
            },
        ],
    }
);
isa_ok( $nm, "Opsview::Schema::Notificationmethods" );
is( $nm->name,                     "okay with spaces" );
is( $nm->variable("AQL_USERNAME"), "changed" );
is_deeply(
    $nm->variables_hash,
    { AQL_USERNAME => 'changed' },
    "only 1 variable, because deleted everytime"
);

$nm = $rs->synchronise(
    {
        name      => "okay with spaces",
        namespace => "newone",
    }
);
is( $nm->namespace, "newone", "Can change namespace" );

$notificationmethod->update( { contact_variables => "" } );
is(
    $notificationmethod->contact_variables,
    "", "contact_variables allowed to be empty"
);

sub test_bad_chars {
    my $string = shift;
    eval { $notificationmethod->update( { command => $string, } ); };
    like(
        $@,
        qr/Failed constraint on command for/,
        "Error with bad characters in $string"
    );
}

test_bad_chars( "../higherlevel" );
test_bad_chars( "withdirs/../higherlevel" );
test_bad_chars( 'with$' );
test_bad_chars( "with `backtick` somewhere" );
test_bad_chars( "with ( in args )" );
test_bad_chars( "with ! in there" );
test_bad_chars( "with * in there" );
test_bad_chars( "with ? in there" );
test_bad_chars( "with ^ in there" );
test_bad_chars( "with %n there" );

$notificationmethod->update( { command => "notify_by_email.exe", } );
is( $notificationmethod->command, "notify_by_email.exe", "Allows dot" );

$rs->update( { active => 1 } );
$expected = [
    {
        variable            => "EMAIL",
        notificationmethods => ["Email"]
    },
    {
        variable            => "PAGER",
        notificationmethods => [ "AQL", "SMS Notification Module" ]
    },
    {
        variable            => "RSS_MAXIMUM_ITEMS",
        notificationmethods => ["RSS"]
    },
    {
        variable            => "RSS_MAXIMUM_AGE",
        notificationmethods => ["RSS"]
    },
    {
        variable            => "RSS_COLLAPSED",
        notificationmethods => ["RSS"]
    },
];
$got = $rs->full_required_variables_list;
is_deeply( $got, $expected );

eval { $notificationmethod->delete };
is( $@, '', "No errors from delete" );
