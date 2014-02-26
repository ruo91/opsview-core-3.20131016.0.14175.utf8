#!/usr/bin/perl
# Tests for changing the opsview db
#
# NOTE: for this tesst to complete correctly
# - in opsview.conf set 'opsview' db name to e 'opsviewdb'
# - run 'db_mysql' to add in grants
# - reset opsview.conf 'opsview' db name back to 'opsview'

use warnings;
use strict;
use FindBin qw($Bin);
use Test::More;

note( "Changing opsview database name to be different" );
system( 'perl', '-i', '-pe', q{s/\$db = "opsview";/\$db = "opsviewdb";/},
    "$Bin/../etc/opsview.conf" ) == 0
  or die "Error changing db name";

note( "Checking that definitely says opsviewdb" );
system( "grep", "-q", "opsviewdb", "$Bin/../etc/opsview.conf" ) == 0
  or die "opsviewdb not changed";

# skip tests if access hasn't been set up correctly on the db
note( 'Testing access to "opsviewdb" has been set up already' );
my $command = $Bin . '/../bin/db_opsview db_exists';

#$command .= ' 2>/dev/null' if ( !$ENV{TEST_VERBOSE} );

if ( system($command ) != 0 ) {
    plan tests => 1;
    fail(
        'database access - amend $db="opsviewdb" in opsview.conf, run SQL commands below (from db_mysql -t)'
    );
    my $message = <<'EOF';
CREATE DATABASE IF NOT EXISTS opsviewdb;
GRANT ALL ON opsviewdb.* TO opsview@localhost IDENTIFIED BY 'changeme';
GRANT ALL ON opsviewdb.* TO opsview@'%' IDENTIFIED BY 'changeme';
GRANT SELECT ON opsviewdb.* TO nagios@'%' IDENTIFIED BY 'changeme';
EOF
    diag($message);
}
else {
    note( "Running hosts tests t/945hosts.t" );
    system( 'perl', "$Bin/945hosts.t" );
}

note( "Changing opsview database name back" );
system( 'perl', '-i', '-pe', q{s/\$db = "opsviewdb";/\$db = "opsview";/},
    "$Bin/../etc/opsview.conf" ) == 0
  or die "Error changing db name";
