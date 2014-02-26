#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More tests => 3;

#use Test::More qw(no_plan);

use_ok( 'Opsview::Test::Cfg' );

use Test::File;
use Test::LongString;

my $bindir     = $Bin . '/../bin/';
my $opsview_sh = $bindir . 'opsview.sh';

file_exists_ok($opsview_sh);

my $output   = `$opsview_sh`;
my $expected = 'ROOT_DIR="/usr/local/nagios"
DB="' . Opsview::Test::Cfg->opsview . '"
DBUSER="opsview"
DBPASSWD="' . Opsview::Test::Cfg->opsview_passwd . '"
DBHOST="localhost"
BACKUP_DIR="/usr/local/nagios/var/backups"
BACKUP_RETENTION_DAYS="30"
DAILY_BACKUP="1"
ARCHIVE_RETENTION_DAYS="180"
RUNTIME_DB="' . Opsview::Test::Cfg->runtime . '"
RUNTIME_DBUSER="nagios"
RUNTIME_DBPASSWD="' . Opsview::Test::Cfg->runtime_passwd . '"
RUNTIME_DBHOST="localhost"
BIND_ADDRESS="0.0.0.0"
USE_LIGHTTPD=0
USE_HTTPS="0"
NMIS_MAXTHREADS="2"
STATUS_DAT="/usr/local/nagios/var/status.dat"
CHECK_RESULT_PATH="/usr/local/nagios/var/spool/checkresults"
OVERRIDES=\'' . Opsview::Test::Cfg->overrides . '\'
OBJECT_CACHE_FILE="/usr/local/nagios/var/objects.cache"
';

is_string( $output, $expected,
    'shell config is as expected - linked to hudson\'s configuration' )
  || diag '=== received ===', $/, $output, '==== expected ===', $/, $expected;
