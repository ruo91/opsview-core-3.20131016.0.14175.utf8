#!/usr/bin/perl
#
#
# Amends the test db so that there are hostgroup/servicegroups which are unused

use warnings;
use strict;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib";
use Opsview::Test;
use File::Path;
use File::Copy;
use Cwd;
use Opsview;
use Opsview::Host;
use Opsview::Contact;
use Opsview::Hostgroup;

plan tests => 2;

my $topdir = "$Bin/../";

my $dbh = Opsview->db_Main;

# Need to make sure there are no contacts for the singlehost hostgroup
# This means that the singlehostgroup host will have no contact groups
# assigned to it
$dbh->do( "UPDATE roles SET all_hostgroups=0,all_servicegroups=0" );
$dbh->do(
    "UPDATE notificationprofiles SET all_hostgroups=0,all_servicegroups=0"
);
$dbh->do(
    'DELETE FROM notificationprofile_hostgroups WHERE hostgroupid = (SELECT id FROM hostgroups WHERE name="singlehost")'
);
ok(
    $dbh->selectrow_array(
        "SELECT COUNT(*) FROM hosts,hostgroups WHERE hosts.hostgroup=hostgroups.id AND hostgroups.name='singlehost'"
    ),
    "Confirmed host exists with a hostgroup that no-one is a contact of"
);

my $here    = "$Bin/var";
my $tmp_dir = "/tmp/configs.$$";
mkdir $tmp_dir or die "Cannot create temporary directory";

( system("$topdir/bin/nagconfgen.pl -t $tmp_dir > /dev/null") == 0 )
  or die "nagconfgen failure";

my @errors;
my @monitoringservers = glob( "$tmp_dir/*" );
foreach my $ms (@monitoringservers) {

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
}
if (@errors) {
    fail( "Failed nagios validation:\n" . join( "\n", @errors ) . "\n" );
}
else {
    pass( "Nagios validation ok for all monitoringservers" );
}
