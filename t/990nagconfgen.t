#!/usr/bin/env perl

# From test db, checks configuration is as expected

use warnings;
use strict;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Opsview::Test qw(stop opsview);
use File::Path;
use File::Copy;
use Cwd;

delete $ENV{DBIC_TRACE_PROFILE};

my $topdir = "$Bin/..";

use_ok( 'Opsview::Test::Cfg' );

my $here    = "$Bin/var";
my $tmp_dir = "/tmp/configs.$$";
mkdir $tmp_dir or die "Cannot create temporary directory $tmp_dir: $!";

# I don't think below is necessary
#( system("perl", "-i", "-e", 's/^\$nrd_shared_password=.*$/$nrd_shared_password="initial"/', "$topdir/etc/opsview.conf") == 0 ) or die "Cannot convert nrd_shared_password back";

my $dbic_trace = "/tmp/configs.$$.dbic_trace";
$ENV{DBIC_TRACE} = "2=$dbic_trace";
( system("$topdir/bin/nagconfgen.pl -t $tmp_dir > /dev/null") == 0 )
  or die "nagconfgen failure";

move( $dbic_trace, "$tmp_dir/dbic_trace" )
  or die "Cannot move $dbic_trace file";

my @errors;
my @monitoringservers = glob( "$tmp_dir/*" );
foreach my $ms (@monitoringservers) {
    next if $ms eq "$tmp_dir/dbic_trace";

    # Take the first of the nodes/ files and copy into node.cfg
    my $here = getcwd();
    chdir($ms);
    my ($first) = glob( "nodes/*.cfg" );
    copy( $first, "node.cfg" ) if $first; # Master does not have a nodes/ dir
    chdir $here;

    local $/ = "";
    my $output = `$topdir/bin/nagios -v "$ms/nagios.cfg"`;
    if ( $? != 0 ) {
        push @errors, $output;
    }

    # Sometimes, Nagios returns warnings
    if ( $output =~ /\nWarning: ?(.*?)\n/ ) {
        push @errors, "Got a warning captured in Nagios validation: $1";
    }

    system("$topdir/bin/nagios -vp '$ms/nagios.cfg'") == 0
      or die "Cannot create precached objects file";
    system(
        "grep -v 'Created:' /usr/local/nagios/var/objects.precache > '$ms/objects.cache'"
    );
}
if (@errors) {
    fail( "Failed nagios validation:\n" . join( "\n", @errors ) . "\n" );
}
else {
    pass( "Nagios validation ok for all monitoringservers" );
}

# Check if runtime database username or password has been changed
# then amend produced output files (carefully) to ensure it doesnt
# break test.  Got to be a better way of doing this, seems too hacky.
if ( Opsview::Test::Cfg->runtime_passwd ne 'changeme' ) {
    system(
        "$^X -p -i -e 's/^password=\\w+/password=changeme/' $tmp_dir/*/*nsca.cfg"
    );
    is( $?, 0, 'Test file correction for nsca config files' );

    system(
        "$^X -p -i -e 's/^db_pass=\\w+/db_pass=changeme/; s/db_name=\\w+/db_name=runtime/' $tmp_dir/*/ndo2db.cfg"
    );
    is( $?, 0, 'Test file correction for ndo2db config files' );
}
else {
    pass( 'No requirement to amend test files' );
    pass( 'No requirement to amend test files' );
}

my $diff = "diff -u -x .svn -x node.cfg -Br $here/configs $tmp_dir";
my $rc   = system( "$diff > /dev/null" );

if ( $? == 0 ) {
    pass( "Nagios configuration matches expected" );
    rmtree($tmp_dir) or die "Cannot remove tree";
}
else {
    fail(
        "Nagios config discrepency!!!\nTest with: $diff\nCopy with: cp -r $tmp_dir/* $here/configs"
    );
    if ( $ENV{OPSVIEW_TEST_HUDSON} ) {
        system( "$diff" );
    }
}

# Cleanup older files, but leave around for a while for debugging
system( 'find /tmp -maxdepth 0 -name "configs.*" -mtime +7 -exec rm -fr {} \;'
);

done_testing;
