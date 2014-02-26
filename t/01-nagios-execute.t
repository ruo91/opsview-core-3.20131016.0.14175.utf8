#!/usr/bin/perl

use Test::More;
use Test::Trap;

plan tests => 20;

use lib "/usr/local/nagios/lib";
use Nagios::Execute;

my $original_env = {%ENV};

my $ne = Nagios::Execute->new( 'env', 'HOST_NAME' => 'testhostname' );

my ( $exit_code, $output );

cmp_ok( $ne->util(), 'eq', 'env', 'util accessor' );

( $exit_code, $output ) = $ne->run();

cmp_ok( $exit_code, '==', 0, 'Exit code' );
cmp_ok( $output, 'eq', "HOST_NAME=testhostname\n", 'Env OK' );

( $exit_code, $output ) = $ne->run( 'HOST_NAME' => 'overrideninrun' );

cmp_ok( $exit_code, '==', 0, 'Exit code' );
cmp_ok( $output, 'eq', "HOST_NAME=overrideninrun\n", 'Env OK' );

( $exit_code, $output ) = $ne->run(
    'HOST_NAME' => 'overrideninrun',
    'HOST_IP'   => '127.0.0.1'
);

cmp_ok( $exit_code, '==', 0, 'Exit code' );
like( $output, qr/HOST_NAME=overrideninrun/, 'overriden HOST_NAME in env' );
like( $output, qr/HOST_IP=127.0.0.1/,        'added HOST_IP in env' );

cmp_ok(
    $ne->util('echo $HOST_NAME'),
    'eq',
    'echo $HOST_NAME',
    'util setter returns set value'
);
cmp_ok( $ne->util(), 'eq', 'echo $HOST_NAME', 'util still set' );

( $exit_code, $output ) = $ne->run();

cmp_ok( $exit_code, '==', 0, 'Exit code' );
cmp_ok( $output, 'eq', "testhostname\n", 'echo output testhostname' );

is_deeply( \%ENV, $original_env, 'Parent process environment not changed' );

# no env
$ne = Nagios::Execute->new( 'env' );

( $exit_code, $output ) = $ne->run();
cmp_ok( $exit_code, '==', 0, 'Exit code' );
cmp_ok( $output || '', 'eq', "", 'no env variables from empty env' );

# non existing
$ne = Nagios::Execute->new( 'nonexistingexecutable' );
trap {
    ( $exit_code, $output ) = $ne->run();
};

cmp_ok( $exit_code, '==', 255, 'Exit code' );
ok( !defined($output), 'no output from nonexisting executable' );
like(
    $trap->stderr,
    qr/"nonexistingexecutable": No such file or directory/,
    'stderr as expected'
);

# return code
$ne = Nagios::Execute->new( 'sh -c \'exit 55\'' );

( $exit_code, $output ) = $ne->run();
cmp_ok( $exit_code, '==', 55, 'Exit code' );
ok( !defined($output), 'exit 1 output nothing' );
