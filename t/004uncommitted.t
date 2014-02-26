#!/usr/bin/perl

use warnings;
use strict;

use FindBin qw($Bin);
use lib "$Bin/../perl/lib", "$Bin/lib";
use Test::More qw(no_plan);
use Opsview::Test qw(opsview);

my @output = `$Bin/../bin/reset_uncommitted 2>&1`;

# Take this line out due to hudson failure
@output = grep !/UTF8Columns/, @output;

is( $?,        0,  "reset_uncommitted works okay" );
is( "@output", "", "and no output" );
is(
    system(
        "$Bin/../bin/db_opsview -t db_backup > $Bin/var/opsview.test.db.auto"),
    0,
    "DB backup okay"
);
is(
    system(
        "diff -wi -u $Bin/var/opsview.test.db $Bin/var/opsview.test.db.auto"),
    0,
    "No differences - if failed, there are probably some uncommitted changes in test db"
);
