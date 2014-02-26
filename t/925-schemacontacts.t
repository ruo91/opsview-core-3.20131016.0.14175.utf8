#!/usr/bin/perl
# This is a test for Opsview::Schema::Contacts

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test;
use utf8;

plan tests => 6;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Contacts" );

my $admin = $rs->search( { name => "admin" } )->first;
isa_ok( $admin, "Opsview::Schema::Contacts" );

my $somehosts = $rs->search( { name => "somehosts" } )->first;
isa_ok( $somehosts, "Opsview::Schema::Contacts" );

is( $somehosts->can_configurehost(4), 1, "Can configure host 4" );
is( $somehosts->can_configurehost(8), 0, "Can configure host 8" );

is( $admin->can_configurehost(4), 1, "Admin can configure everything" );
is( $admin->can_configurehost(8), 1, "Admin can configure everything" );
