#!/usr/bin/perl

use Test::More tests => 5;

use lib "lib", "etc";
use lib '/usr/local/nagios/lib';
use strict;
use Opsview;
use DateTime;

my $dbh = Opsview->db_Main;
ok( defined $dbh, "Connect to db" );

my %tables;
my $sth = $dbh->table_info( undef, undef, "%", "TABLE" );
while ( $_ = $sth->fetchrow_hashref ) {
    $tables{ $_->{TABLE_NAME} }++;
}

ok( scalar keys %tables > 5, "More than 5 tables defined" );
ok( $tables{contacts},       "And contacts table is there" );

$_ = system( "sh /usr/local/nagios/bin/profile" );
is( $_, 0, "/usr/local/nagios/bin/profile must return 0" );

my $time_object = DateTime->now( time_zone => 'local' );
like(
    $time_object->time_zone_short_name,
    qr/^(UTC)$/, 'Some tests may fail if server timezone is not set to "UTC"'
);
