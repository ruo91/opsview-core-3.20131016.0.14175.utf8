
use strict;
use warnings;

BEGIN {
    use FindBin qw($Bin);
    chdir( "$Bin/.." );
}

use lib "$Bin/lib";

my @TEST_CLASS =
  exists $ENV{TEST_CLASS}
  ? split( /\s*,\s*/, $ENV{TEST_CLASS} )
  : ();

use Test::Class::Load "$Bin/tests";
Test::Class->runtests(@TEST_CLASS);

Test::Opsview->_final_shutdown_testing;
