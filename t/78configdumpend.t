#!/usr/bin/perl

#BEGIN { system("/usr/local/nagios/bin/rc.opsview stop") }

use Test::More tests => 4;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test;
use Opsview;
use Opsview::Config;
use Runtime;

chdir( "$Bin/.." );

my $dbh = Runtime->db_Main;
ok( defined $dbh, "Connect to db" );

my @tables =
  qw(opsview_contacts opsview_contact_services opsview_host_services opsview_hostgroups opsview_hostgroup_hosts opsview_monitoringservers
  opsview_monitoringclusternodes opsview_hosts opsview_viewports opsview_performance_metrics opsview_host_objects opsview_servicechecks opsview_servicegroups);

my $mysqldump =
  "mysqldump --compatible=mysql40 --skip-extended-insert --comments=FALSE --complete-insert=FALSE --order-by-primary=TRUE --quote-names -u "
  . Opsview::Config->runtime_dbuser . " -p"
  . Opsview::Config->runtime_dbpasswd . " "
  . Opsview::Config->runtime_db . " "
  . join( " ", @tables );

$ENV{OPSVIEW_TEST_ROOTDIR} = $Bin;

my $rc = system( "/usr/local/nagios/bin/ndoutils_configdumpend" );
is( $rc, 0, "ndoutils_configdumpend ran successfully" );

$rc = system( "$mysqldump | grep -v ^SET > t/var/configdumpend.generated" );
is( $rc, 0, "mysqldump finished" );

SKIP:
{
    my $diff =
      "diff -wi -u t/var/configdumpend.expected t/var/configdumpend.generated";
    my $output = `$diff`;
    $rc = $?;
    if ( $rc == 0 ) {
        pass( "Configdump as expected" );
    }
    else {
        if ( $ENV{OPSVIEW_TEST_HUDSON} ) {
            fail( "Configdump not as expected - ignore if not on Hudson" );
        }
        else {
            pass( "We pass this because not run on Hudson, but check diffs" );
        }
        diag( "Use '$diff' to check" );
        diag(
            "Use 'cp t/var/configdumpend.generated t/var/configdumpend.expected' to copy, if correct"
        );
        diag($output);
    }
}
