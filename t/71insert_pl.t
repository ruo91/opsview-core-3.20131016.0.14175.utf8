#!/usr/bin/perl
# Had test failures in insert.pl - this checks if it works correctly

use Test::More qw(no_plan);

use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Opsview::Utils::PerfdatarrdImporter;
use Log::Log4perl;

system("rm -fr $Bin/../var/rrd/*") == 0 or die "Cannot cleanup rrd dir";

open F, "$Bin/var/perfdata.log" or die "Cannot open perfdata.log";
my @data = <F>;
close F;

Log::Log4perl->init(
    {
        "log4perl.rootLogger"      => "INFO, Screen",
        "log4perl.appender.Screen" => "Log::Log4perl::Appender::Screen",
        "log4perl.appender.Screen.layout" =>
          "Log::Log4perl::Layout::SimpleLayout",
    }
);

my $logger = Log::Log4perl->get_logger();

my $importer =
  Opsview::Utils::PerfdatarrdImporter->new( { logger => $logger, } );
isa_ok( $importer, "Opsview::Utils::PerfdatarrdImporter" );
$importer->processdata( \@data );
pass( "Import okay - will get one warning message above, but can be ignored" );

is_uom( "mail/HTTP/time/uom",                                        "s" );
is_uom( "cisco/Interface%3A%20FastEthernet0%2F22/throughput_in/uom", "b" );

ok(
    !-e "$Bin/../var/rrd/opslave/TCP%2FIP%20%2D%20LAN/rta/uom",
    "No uom file here, as expected"
);

sub is_uom {
    my ( $file, $name, $output ) = @_;
    open F, "$Bin/../var/rrd/$file" or die "Can't open uom $file: $!";
    my $uom = "";
    { local $/ = undef; $uom = <F>; chomp $uom; }
    close F;
    is( $uom, $name, $output );
}
