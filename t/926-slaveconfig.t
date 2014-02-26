#!/usr/bin/perl

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";

plan tests => 2;

use_ok( "Opsview::Slave::Config" );
my $override_base_prefix = Opsview::Slave::Config->override_base_prefix;
is( $override_base_prefix, "", "Slave config read" );
