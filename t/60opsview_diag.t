#!/usr/bin/perl
#
# check opsview_diag compiles and generates valid reports
# without any runtime errors
#
# output of the report doesnt matter much at this stage

use warnings;
use strict;

use FindBin qw($Bin);
use lib "$Bin/lib";
use Opsview::Test qw(opsview);

use Test::More;

# We have to remove these monitoringservers otherwise opsview_diag will try to connect
# to them, which is not possible in testing scenarios. This saves about 6 minutes in the test
is(
    system("$Bin/../utils/test_db_post"),
    0, "Removed monitoring servers from test DB"
);

chdir( "$Bin/.." );

# no point running if it doesnt compile
my $output = qx! $^X -c bin/opsview_diag 2>&1 !;
chomp($output);
if ($?) {
    BAIL_OUT( 'Failed to compile opsview_diag: ' . $output );
}

my @categories = qx! bin/opsview_diag -l !;
shift @categories; # remove first line;

# tidy up list
map { chomp; s/\s*-\s*// } @categories;

#plan tests => scalar(@categories) + 1;

for my $report (@categories) {
    note( "Running 'opsview_diag $report:3'" );

    my $output = qx! bin/opsview_diag $report:3 !;
    is( $?, 0, $report . ':3 - Report ran OK' );
}

done_testing();
