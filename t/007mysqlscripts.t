#!/usr/bin/perl
# Test upgrade scripts for known issues
use strict;
use warnings;

use FindBin qw($Bin);

use Test::More qw/no_plan/;

my $errors = 0;
my $script;
chdir("$Bin/../installer") or die "Cannot chdir: $!";
foreach (<upgrade*.pl>) {
    $script = $_;
    open F, "$script" or die "Can't open $script";
    while (<F>) {
        check_for_wrong_type($_);
    }
    close F;
}

chdir("$Bin/../bin") or die "Cannot chdir: $!";
foreach (<db_*>) {
    $script = $_;
    open F, "$script" or die "Can't open $script";
    while (<F>) {
        check_for_wrong_type($_);
    }
    close F;
}

if ($errors) {
    fail( "Found $errors errors" );
}
else {
    pass( "All scripts ok" );
}

sub check_for_wrong_type {
    my $line = shift;
    if ( $line =~ m/TYPE\s*=\s*InnoDB/i ) {
        diag(
            "Found TYPE=InnoDB in $script at line $. - use ENGINE=InnoDB instead"
        );
        $errors++;
    }
}
