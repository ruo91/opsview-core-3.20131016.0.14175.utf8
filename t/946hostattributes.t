#!/usr/bin/perl
# Tests for Opsview::ResultSet::Attributes

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Attributes" );

my $disk = $rs->find( { name => "DISK" } );
isa_ok( $disk, "Opsview::Schema::Attributes" );

is(
    $disk->hostattributes->count,
    8, "Found all disk attributes related to hosts"
);
is( $disk->hosts->count, 8, "Also can get to hosts list" );
is( $disk->servicechecks->count, 4, );

my @hosts = $disk->hosts( {}, { distinct => 1 } );
my @hostnames;
@hostnames = map { $_->name } @hosts;
is_deeply(
    \@hostnames,
    [
        qw(monitored_by_cluster monitored_by_slave opsview opsviewdev1 opsviewdev46)
    ],
);

my $nrpe = $rs->find( { name => "NRPE_PORT" } );
@hosts = $nrpe->hosts( {}, { distinct => 1 } );
is( scalar @hosts, 2, "Only 2 with NRPE_PORT" );
@hostnames = map { $_->name } @hosts;
is_deeply( \@hostnames, [ "opsview", "resolved_services" ] );

my $validation = $rs->validation_regexp;
is_deeply(
    $validation,
    {
        name  => '/^[A-Z0-9_]{1,63}$/',
        value => '/^[\w ./-]{1,63}$/'
    },
    "Validation as expected"
);

$validation = $schema->resultset("HostAttributes")->validation_regexp;
is_deeply(
    $validation,
    { value => '/^[\w ./-]{1,63}$/' },
    "Validation for values as expected"
);

$nrpe = $rs->synchronise(
    {
        name  => "NRPE_PORT",
        value => "5666  ",
        arg1  => "any old iron, any old iron, any any any old iron",
    }
);
is( $nrpe->value, 5666, "Check value has trailing spaces removed" );
is( $nrpe->arg1, "any old iron, any old iron, any any any old iron" );

eval { $rs->synchronise( { name => "NRPE_PORT", value => 'bad%char$again' } ) };
is( $@, "value: Invalid\n" );

eval { $rs->synchronise( { name => "ORACLE_10G", value => 'valid' } ) };
is( $@, "", "Allow numbers" );
