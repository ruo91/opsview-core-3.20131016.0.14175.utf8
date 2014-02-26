use strict;
use warnings;

use Test::More tests => 23;

#use Test::More qw(no_plan);
use Test::Trap;

# cannot use currently due to 3rd party bugs with UNIVERSAL::can
#  -> Called UNIVERSAL::can() as a function, not a method at /usr/local/nagios/perl/lib/Class/Trigger.pm line 113
# Raised bug at http://rt.cpan.org/Ticket/Display.html?id=45851
#use Test::NoWarnings;

use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/lib", "$Bin/../etc";

use Opsview::Test qw(opsview);

use Test::MockObject::Extends;

use_ok( 'Opsview::Servicecheck' );

my $check = Opsview::Servicecheck->new();
isa_ok( $check, 'Opsview::Servicecheck' );

$check = Test::MockObject::Extends->new($check);
isa_ok( $check, 'Opsview::Servicecheck' );

$check->set_false( 'agent' );
$check->set_always( 'plugin', 'plugin' );

# normal checks
$check->set_false( 'invertresults' );

is( $check->command(), 'plugin', 'no args ok' );
is(
    $check->command( args => 'plain text' ),
    'plugin plain text',
    'plain text ok'
);

is(
    $check->command( args => 'single dollar $' ),
    'plugin single dollar $',
    'single dollar ok'
);
is(
    $check->command( args => 'escaped single dollar \$' ),
    'plugin escaped single dollar \$',
    'escaped single dollar ok'
);
is(
    $check->command( args => 'double dollar $$' ),
    'plugin double dollar $$',
    'double dollar ok'
);
is(
    $check->command( args => 'escaped double dollar \$\$' ),
    'plugin escaped double dollar \$\$',
    'escaped double dollar ok'
);

is(
    $check->command( args => 'single shriek !' ),
    'plugin single shriek \!',
    'single shriek ! ok'
);
is(
    $check->command( args => 'escaped single shriek \!' ),
    'plugin escaped single shriek \!',
    'escaped single shriek ! ok'
);
is(
    $check->command( args => 'double shriek !!' ),
    'plugin double shriek \!\!',
    'double shriek ! ok'
);
is(
    $check->command( args => 'escaped double shriek \!\!' ),
    'plugin escaped double shriek \!\!',
    'escaped double shriek ! ok'
);

# inverted checks
$check->set_true( 'invertresults' );

is( $check->command(), 'my_negate plugin', 'no args ok' );
is(
    $check->command( args => 'plain text' ),
    'my_negate plugin plain text',
    'plain text ok'
);

is(
    $check->command( args => 'single dollar $' ),
    'my_negate plugin single dollar $',
    'single dollar ok'
);
is(
    $check->command( args => 'escaped single dollar \$' ),
    'my_negate plugin escaped single dollar \$',
    'escaped single dollar ok'
);
is(
    $check->command( args => 'double dollar $$' ),
    'my_negate plugin double dollar $$',
    'double dollar ok'
);
is(
    $check->command( args => 'escaped double dollar \$\$' ),
    'my_negate plugin escaped double dollar \$\$',
    'escaped double dollar ok'
);

is(
    $check->command( args => 'single shriek !' ),
    'my_negate plugin single shriek \!',
    'single shriek ! ok'
);
is(
    $check->command( args => 'escaped single shriek \!' ),
    'my_negate plugin escaped single shriek \!',
    'escaped single shriek ! ok'
);
is(
    $check->command( args => 'double shriek !!' ),
    'my_negate plugin double shriek \!\!',
    'double shriek ! ok'
);
is(
    $check->command( args => 'escaped double shriek \!\!' ),
    'my_negate plugin escaped double shriek \!\!',
    'escaped double shriek ! ok'
);
