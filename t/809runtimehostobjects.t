#!/usr/bin/env perl

use strict;
use warnings;

use Test::Deep;
use Test::More tests => 3;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use Opsview::Test;
use Runtime::Schema;

my $schema = Runtime::Schema->my_connect;

my $rs = $schema->resultset( "OpsviewHostObjects" );

my $opsview = $rs->search(
    {
        hostname => "opsview",
        name2    => "Slave-node: opslave"
    }
)->first;
isa_ok( $opsview, "Runtime::Schema::OpsviewHostObjects", "Found opsview host"
);
can_ok( $opsview, 'expand_link_macros' );
is(
    $opsview->expand_link_macros(
        'http://example.com/hostgroupname=$HOSTGROUPNAME$;hostaddress=$HOSTADDRESS$;hostname=$HOSTNAME$;servicename=$SERVICENAME$;servicecheckname=$SERVICECHECKNAME$'
    ),
    'http://example.com/hostgroupname=$HOSTGROUPNAME$;hostaddress=localhost;hostname=opsview;servicename=Slave-node: opslave;servicecheckname=Slave-node',
    "expand_link_macros is good"
);
