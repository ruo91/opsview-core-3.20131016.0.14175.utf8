#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use lib "/usr/local/nagios/lib";

use Utils::Weberrors;

my $errors = [
    {
        error => [
            "Table 'runtime.nagios_hosts' is marked as crashed and should be repaired"
        ],
        url_end => 'mysql#fixing_damaged_database_tables',
    },
    {
        error => [
            "Two lots of messages",
            "Table 'runtime.nagios_hosts' is marked as crashed and should be repaired",
            "Only 1 url_end returned"
        ],
        url_end => 'mysql#fixing_damaged_database_tables',
    },
    {
        error => [
            qq{{Opsview error: Caught exception in Opsview::Web::Controller::Admin::Servicecheck->save_new "validate_column_values error: name Opsview::Servicegroup name fails 'regexp' constraint with 'single: work' at /usr/local/nagios/perl/lib/Class/Trigger.pm line 74
 at /var/log/nagios/opsview-3/opsview-web/script/../lib/Opsview/Web/ControllerBase/Admin.pm line 348}}
        ],
        url_end => 'help#validation_errors',
    },
    {
        error   => ["A message that is not in the list"],
        url_end => "webexception",
    },
];

plan tests => scalar @$errors;

foreach my $test (@$errors) {
    is(
        Utils::Weberrors->lookup_errors( $test->{error} ),
        $test->{url_end}, "Got url_end: " . ( $test->{url_end} || "undef" )
    );
}
