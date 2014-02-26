#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 127;

#use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$Bin/../lib", "t/lib";
use POSIX qw(strftime);

use_ok( "Opsview::Externalcommand" );

my ( $object1, $object2 );
my $master_file = "/tmp/master_file";
my $slave_file  = "/tmp/slave_file";
my $now;
my ( $command1, $command2, $args1, $args2, @args1, @args2 );

sub tidy {
    for my $file ( $master_file, $slave_file ) {
        if ( -f $file ) {
            unlink($file) || die( "Unable to remove $file: $!" );
        }
    }
}

sub read_file {
    my $file = shift;
    local $/ = undef;
    return undef unless ( -s $file );
    open( FILE, "<", $file ) || die( "Unable to open $file: $!" );
    my $contents = <FILE>;
    close(FILE);
    return $contents;
}

tidy();

diag("Creating and configuring object") if ( $ENV{TEST_VERBOSE} );
$object1 = Opsview::Externalcommand->new(
    master_file => $master_file,
    slave_file  => $slave_file,
);
isa_ok( $object1, "Opsview::Externalcommand", "created object ok" );
is( $object1->master_file, $master_file, "Redirected master file" );
is( $object1->slave_file,  $slave_file,  "Redirected slave file" );

$object2 = new Opsview::Externalcommand;
isa_ok( $object2, "Opsview::Externalcommand", "created object ok" );
is(
    $object2->master_file($master_file),
    $master_file, "Redirected master file"
);
is( $object2->slave_file($slave_file), $slave_file, "Redirected slave file" );

diag("Sending simple commands") if ( $ENV{TEST_VERBOSE} );
$command1 = "THIS_IS_A_COMMAND";
$args1    = "argument";
is( $object1->command($command1), $command1, "command set" );
is( $object1->args($args1),       $args1,    "args set" );

$now = time();
$object1->send_to_master;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_master file ok"
);
is( read_file($slave_file), undef, "send_to_master slave file ok" );
tidy();

$now = time();
$object1->send_to_slaves;
is( read_file($master_file), undef, "send_to_slave master file ok" );
is( read_file($slave_file), "$command1;$args1\n", "send_to_slaves file ok" );
tidy();

$now = time();
$object1->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "submit master file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "submit slaves file ok" );
tidy();

$now = time();
$object1->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_all master file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "send_to_all slaves file ok"
);
tidy();

diag("Sending more complex string command") if ( $ENV{TEST_VERBOSE} );
$command1 = "THIS_IS_NOT_A_COMMAND";
$args1    = "arg5;arg6;arg7";
is( $object1->command($command1), $command1, "command set" );
is( $object1->args($args1),       $args1,    "args set" );

$now = time();
$object1->send_to_master;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_master file ok"
);
is( read_file($slave_file), undef, "send_to_master slave file ok" );
tidy();

$now = time();
$object1->send_to_slaves;
is( read_file($master_file), undef, "send_to_slave master file ok" );
is( read_file($slave_file), "$command1;$args1\n", "send_to_slaves file ok" );
tidy();

$now = time();
$object1->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "submit master file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "submit slaves file ok" );
tidy();

$now = time();
$object1->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_all master file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "send_to_all slaves file ok"
);
tidy();

diag("Sending more complex array command") if ( $ENV{TEST_VERBOSE} );
$command1 = "THIS_ISNT_A_COMMAND";
$args1    = "arg5;arg6;arg7";
@args1    = split( ";", $args1 );
is( $object1->command($command1), $command1, "command set" );
is( $object1->args(@args1),       $args1,    "args set" );

$now = time();
$object1->send_to_master;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_master file ok"
);
is( read_file($slave_file), undef, "send_to_master slave file ok" );
tidy();

$now = time();
$object1->send_to_slaves;
is( read_file($master_file), undef, "send_to_slave master file ok" );
is( read_file($slave_file), "$command1;$args1\n", "send_to_slaves file ok" );
tidy();

$now = time();
$object1->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "submit master file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "submit slaves file ok" );
tidy();

$now = time();
$object1->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_all master file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "send_to_all slaves file ok"
);
tidy();

diag("Sending multiple commands") if ( $ENV{TEST_VERBOSE} );
$command1 = "THIS_MAYBE_A_COMMAND";
$command2 = "THIS_MAYBE_A_SECOND_COMMAND";
$args1    = "arg8;arg9;arg10";
$args2    = "brg8;brg9;brg10";
is( $object1->command($command1), $command1, "command set" );
is( $object1->args($args1),       $args1,    "args set" );
is( $object2->command($command2), $command2, "command set" );
is( $object2->args($args2),       $args2,    "args set" );

$now = time();
$object1->send_to_master;
$object2->send_to_master;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "send_to_master multiple file ok"
);
is( read_file($slave_file), undef, "send_to_master multiple slave file ok" );
tidy();

$now = time();
$object1->send_to_slaves;
$object2->send_to_slaves;
is( read_file($master_file), undef, "send_to_slave multiple master file ok" );
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "send_to_slaves multiple file ok"
);
tidy();

$now = time();
$object1->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "submit master file file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "submit slaves file file ok"
);
tidy();

$now = time();
$object1->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_all master file file ok"
);
is( read_file($slave_file), "$command1;$args1\n",
    "send_to_all slaves file file ok"
);
tidy();

diag("Sending multiple commands with array") if ( $ENV{TEST_VERBOSE} );
$command1 = "THIS_WAS_A_COMMAND";
$command2 = "THIS_WAS_A_SECOND_COMMAND_TOO";
$args1    = "arg11;arg12;arg13";
@args1    = split( ";", $args1 );
$args2    = "brg11;brg12;brg13";
@args2    = split( ";", $args2 );
is( $object1->command($command1), $command1, "command set" );
is( $object1->args(@args1),       $args1,    "args set" );
is( $object2->command($command2), $command2, "command set" );
is( $object2->args(@args2),       $args2,    "args set" );

$now = time();
$object1->send_to_master;
$object2->send_to_master;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "send_to_master multiple file ok"
);
is( read_file($slave_file), undef, "send_to_master multiple slave file ok" );
tidy();

$now = time();
$object1->send_to_slaves;
$object2->send_to_slaves;
is( read_file($master_file), undef, "send_to_slave multiple master file ok" );
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "send_to_slaves multiple file ok"
);
tidy();

$now = time();
$object1->submit;
$object2->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "submit multiple file ok"
);
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "submit slaves file file ok"
);
tidy();

$now = time();
$object1->send_to_all;
$object2->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "send_to_all multiple file ok"
);
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "send_to_all slaves file file ok"
);
tidy();

diag("Creating and configuring object at creation time with scalar args")
  if ( $ENV{TEST_VERBOSE} );
$command1 = "New Command";
$args1    = "arg14;arg15;arg16";
@args1    = split( ";", $args1 );
$object1  = new Opsview::Externalcommand(
    command => $command1,
    args    => $args1,
);
isa_ok( $object1, "Opsview::Externalcommand", "created object ok" );
is(
    $object1->master_file($master_file),
    $master_file, "Redirected master file"
);
is( $object1->slave_file($slave_file), $slave_file, "Redirected slave file" );
is( $object1->command(),               $command1,   "command set" );
is( $object1->args(),                  $args1,      "args set to :$args1:" );

$now = time();
$object1->send_to_master;
is( read_file($master_file), "[$now] $command1;$args1\n", "send_to_master ok"
);
is( read_file($slave_file), undef, "send_to_master ok" );
tidy();

$now = time();
$object1->send_to_slaves;
is( read_file($master_file), undef, "send_to_slave ok" );
is( read_file($slave_file), "$command1;$args1\n", "send_to_slaves ok" );
tidy();

$now = time();
$object1->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "submit multiple file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "submit slaves file file ok"
);
tidy();

$now = time();
$object1->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_all multiple file ok"
);
is( read_file($slave_file), "$command1;$args1\n",
    "send_to_all slaves file file ok"
);
tidy();

diag("Creating and configuring object at creation time with scalar args")
  if ( $ENV{TEST_VERBOSE} );
$command1 = "New Command";
diag("Creating and configuring object at creation time with array args")
  if ( $ENV{TEST_VERBOSE} );
$object1 = new Opsview::Externalcommand(
    command => $command1,
    args    => \@args1,
);
isa_ok( $object1, "Opsview::Externalcommand", "created object ok" );
is(
    $object1->master_file($master_file),
    $master_file, "Redirected master file"
);
is( $object1->slave_file($slave_file), $slave_file, "Redirected slave file" );
is( $object1->command(),               $command1,   "command set" );
is( $object1->args(),                  $args1,      "args set to :$args1:" );

$now = time();
$object1->send_to_master;
is( read_file($master_file), "[$now] $command1;$args1\n", "send_to_master ok"
);
is( read_file($slave_file), undef, "send_to_slaves ok" );
tidy();

$now = time();
$object1->send_to_slaves;
is( read_file($master_file), undef, "send_to_master ok" );
is( read_file($slave_file), "$command1;$args1\n", "send_to_slaves ok" );
tidy();

$now = time();
$object1->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "submit multiple file ok"
);
is( read_file($slave_file), "$command1;$args1\n", "submit slaves file file ok"
);
tidy();

$now = time();
$object1->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n",
    "send_to_all multiple file ok"
);
is( read_file($slave_file), "$command1;$args1\n",
    "send_to_all slaves file file ok"
);
tidy();

diag("Creating and configuring object at creation time with scalar args")
  if ( $ENV{TEST_VERBOSE} );
$command1 = "New Command";
diag("Creating and configuring object at creation time with array args")
  if ( $ENV{TEST_VERBOSE} );
$object1 = new Opsview::Externalcommand(
    command => $command1,
    args    => $args2,
);
diag("Creating two objects and configuring at creation time with scalar args")
  if ( $ENV{TEST_VERBOSE} );
$command1 = "New Command";
$args1    = "arg14;arg15;arg16";
@args1    = split( ";", $args1 );
$object1  = new Opsview::Externalcommand(
    command => $command1,
    args    => $args1,
);
isa_ok( $object1, "Opsview::Externalcommand", "created object ok" );
is(
    $object1->master_file($master_file),
    $master_file, "Redirected master file"
);
is( $object1->slave_file($slave_file), $slave_file, "Redirected slave file" );
is( $object1->command(),               $command1,   "command set" );
is( $object1->args(),                  $args1,      "args set to :$args1:" );
$command2 = "Second New Command";
$args2    = "brg14;brg15;brg16";
@args2    = split( ";", $args2 );
$object2  = new Opsview::Externalcommand(
    command => $command2,
    args    => $args2,
);
isa_ok( $object2, "Opsview::Externalcommand", "created second object ok" );
is(
    $object2->master_file($master_file),
    $master_file, "Redirected master file"
);
is( $object2->slave_file($slave_file), $slave_file, "Redirected slave file" );
is( $object2->command(),               $command2,   "command set" );
is( $object2->args(),                  $args2,      "args set to :$args2:" );

$now = time();
$object1->send_to_master;
$object2->send_to_master;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "send_to_master multiple file ok"
);
is( read_file($slave_file), undef, "send_to_master multiple file ok" );
tidy();

$now = time();
$object1->send_to_slaves;
$object2->send_to_slaves;
is( read_file($master_file), undef, "send_to_slave multiple file ok" );
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "send_to_slaves multiple file ok"
);
tidy();

$now = time();
$object1->submit;
$object2->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "submit multiple file ok"
);
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "submit slaves file file ok"
);
tidy();

$now = time();
$object1->send_to_all;
$object2->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "send_to_all multiple file ok"
);
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "send_to_all slaves file file ok"
);
tidy();

diag("Creating two objects and configuring at creation time with array args")
  if ( $ENV{TEST_VERBOSE} );
$object1 = new Opsview::Externalcommand(
    command => $command1,
    args    => \@args1,
);
isa_ok( $object1, "Opsview::Externalcommand", "created object ok" );
is(
    $object1->master_file($master_file),
    $master_file, "Redirected master file"
);
is( $object1->slave_file($slave_file), $slave_file, "Redirected slave file" );
is( $object1->command(),               $command1,   "command set" );
is( $object1->args(),                  $args1,      "args set to :$args1:" );
$command2 = "Second New Command";
$args2    = "brg14;brg15;brg16";
@args2    = split( ";", $args2 );
$object2  = new Opsview::Externalcommand(
    command => $command2,
    args    => \@args2,
);
isa_ok( $object2, "Opsview::Externalcommand", "created second object ok" );
is(
    $object2->master_file($master_file),
    $master_file, "Redirected master file"
);
is( $object2->slave_file($slave_file), $slave_file, "Redirected slave file" );
is( $object2->command(),               $command2,   "command set" );
is( $object2->args(),                  $args2,      "args set to :$args2:" );

$now = time();
$object1->send_to_master;
$object2->send_to_master;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "send_to_master multiple file ok"
);
is( read_file($slave_file), undef, "send_to_master multiple file ok" );
tidy();

$now = time();
$object1->send_to_slaves;
$object2->send_to_slaves;
is( read_file($master_file), undef, "send_to_slaves multiple file ok" );
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "send_to_slaves multiple file ok"
);
tidy();

$now = time();
$object1->submit;
$object2->submit;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "submit multiple file ok"
);
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "submit slaves file file ok"
);
tidy();

$now = time();
$object1->send_to_all;
$object2->send_to_all;
is(
    read_file($master_file),
    "[$now] $command1;$args1\n[$now] $command2;$args2\n",
    "send_to_master multiple file ok"
);
is(
    read_file($slave_file),
    "$command1;$args1\n$command2;$args2\n",
    "send_to_all slaves file file ok"
);
tidy();

# Test that linefeeds are not allowed
$object1 = new Opsview::Externalcommand(
    command => "TESTING SECURITY",
    args    => "weakness\nAnother command to execute",
);
is(
    $object1->master_file($master_file),
    $master_file, "Redirected master file"
);
eval { $_ = $object1->send_to_master };
is( $_, undef, "Got undef due to bad characters" );
is( $@, "Command contains invalid characters\n" );
is( read_file($master_file), undef,
    "Command blocked from being passed to external file",
);
