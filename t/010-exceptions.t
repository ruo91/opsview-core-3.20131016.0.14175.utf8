#!/usr/bin/env perl

use strict;
use warnings;

use FindBin '$Bin';
use lib "$FindBin::Bin/../lib";

use Opsview::Exceptions
  qw( throw_data_malformed throw_http throw_param throw_system );
use Test::Most tests => 4;

subtest 'throw_http' => sub {
    plan tests => 9;
    throws_ok { throw_http 'http error' } 'Opsview::Exceptions::HTTP';
    throws_ok { throw_http 'http error' } qr/http error/;
    throws_ok { throw_http code => 503, error => 'service unavailable' }
    'Opsview::Exceptions::HTTP';
    throws_ok { throw_http code => 503, error => 'service unavailable' }
    qr/service unavailable/;
    eval { throw_http code => 503, error => 'service unavailable' };
    my $e = $@;
    isa_ok( $e, 'Opsview::Exceptions' );
    isa_ok( $e, 'Opsview::Exceptions::HTTP' );
    is( $e->error,       'service unavailable',  'error is correct' );
    is( $e->code,        503,                    'code is correct' );
    is( $e->description, 'HTTP transport layer', 'description is correct' );
};

subtest 'throw_param' => sub {
    plan tests => 6;
    throws_ok { throw_param 'param error' } 'Opsview::Exceptions::Parameter';
    throws_ok { throw_param 'param error' } qr/param error/;
    eval { throw_param 'param error' };
    my $e = $@;
    isa_ok( $e, 'Opsview::Exceptions' );
    isa_ok( $e, 'Opsview::Exceptions::Parameter' );
    is( $e->error,       'param error', 'error is correct' );
    is( $e->description, 'parameter',   'description is correct' );
};

subtest 'throw_data_malformed' => sub {
    plan tests => 6;
    throws_ok { throw_data_malformed 'malformed error' }
    'Opsview::Exceptions::Data::Malformed';
    throws_ok { throw_data_malformed 'malformed error' } qr/malformed error/;
    eval { throw_data_malformed 'malformed error' };
    my $e = $@;
    isa_ok( $e, 'Opsview::Exceptions' );
    isa_ok( $e, 'Opsview::Exceptions::Data::Malformed' );
    is( $e->error, 'malformed error', 'error is correct' );
    is(
        $e->description,
        'malformed or unexpected data',
        'description is correct'
    );
};

subtest 'throw_system' => sub {
    plan tests => 6;
    throws_ok { throw_system 'system error' } 'Opsview::Exceptions::System';
    throws_ok { throw_system 'system error' } qr/system error/;
    eval { throw_system 'system error' };
    my $e = $@;
    isa_ok( $e, 'Opsview::Exceptions' );
    isa_ok( $e, 'Opsview::Exceptions::System' );
    is( $e->error,       'system error', 'error is correct' );
    is( $e->description, 'system level', 'description is correct' );
};
