#!/usr/bin/perl

use Test::More qw(no_plan);

use FindBin qw($Bin);
use File::Next;

my $file_filter = sub { $_ && $_ =~ m/info$/ };
my $opspack_files = File::Next::files(
    { file_filter => $file_filter, },
    "$Bin/../import/opspacks_source/"
);
while ( defined( my $info = $opspack_files->() ) ) {
    open INFO, $info or die "Cannot read $info: $!";
    my @lines = <INFO>;
    my $goodname = grep {/NAME=com\.opsview\.opspack/} @lines;
    close INFO;
    if ($goodname) {
        pass( "Got good name for opspack" );
    }
    else {
        fail( "Got bad name for opspack $lines[0]" );
    }
}
