#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use JSON;
use Opsview::Utils::XMLSerialisation;
use Data::Dump qw(dump);
use Clone qw(clone);

my $json  = JSON->new->relaxed(1);
my $toxml = Opsview::Utils::XMLSerialisation->new;

my $xmldir = "$Bin/var/xmlserialisation";
opendir TESTCASES, $xmldir || die "Can't read dir: $xmldir";
foreach my $testcase ( readdir TESTCASES ) {
    next unless ( $testcase =~ /\.json$/ );
    print "Got $xmldir/$testcase\n";
    my $file;
    open F, "$xmldir/$testcase" or die "Can't open file";
    {
        local $/ = undef;
        $file = <F>;
    }
    close F;
    my $hash     = $json->decode($file);
    my $original = clone($hash);

    my $result = $toxml->serialise($hash);

    #print "$result";

    my $converted_back = $toxml->deserialise($result);

    is_deeply( $converted_back, $original, "Conversion back worked" ) || diag(
            "Original:"
          . dump($original)
          . "\nXML:"
          . $result
          . "\nConverted back:"
          . dump($converted_back)
    );
}
closedir TESTCASES;
