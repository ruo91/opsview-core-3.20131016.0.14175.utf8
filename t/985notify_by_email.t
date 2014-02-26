#!/usr/bin/perl
#
# Tests that notfy_by_email returns the right data for emailing

use warnings;
use strict;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use File::Path;
use File::Copy;
use Cwd;
use Data::Dump;

my $topdir = "$Bin/..";

plan 'no_plan';

chdir($topdir) or die;

my $expected = [
    'TESTING OUTPUT',
    '',
    'PROBLEM: cisco is DOWN',
    '',
    '',
    'Host: cisco',
    'Alias: temp host 1',
    'Address: 10.11.12.13',
    'Host Group Hierarchy: Opsview > UK > Leaf',
    'State: DOWN',
    'Date & Time: Dec 1 2009',
    '',
    'Additional Information: ',
    '',
    'Test host failure',
    'More data returned from Nagios',
    'Which could be over',
    'multiple lines',
    '',
    '',
    ''
];

# Override config file for testing purposes
$ENV{OPSVIEW_SLAVE_CONFIGFILE} =
  "$Bin/var/configs/Master Monitoring Server/notificationmethodvariables.cfg";

# Override hostname, so that it reads data from the config file
$ENV{NAGIOS_HOSTNAME}      = "cisco";
$ENV{NAGIOS_HOSTGROUPNAME} = "Leaf";

my @output = map { s/\n$//; $_ }
  `utils/test_notifications hostproblem notifications/notify_by_email -t 2>&1`;

# This could also fail if the notify_by_email script closes stdin and stderr - we add an envvar check to let hudson show output
is_deeply( \@output, $expected,
    "Email notification as expected for normal template" )
  || diag Data::Dump::dump(@output);

$expected = [
    "TESTING OUTPUT",
    "Hierarchy:Opsview > UK > Leaf",
    "Hostname:cisco",
    "Service:",
    "Status:DOWN",
    "Timestamp:0",
    "Retries:1",
    "Additional Information:Test host failure",
    "More data returned from Nagios",
    "Which could be over",
    "multiple lines",
];
copy(
    "$topdir/t/var/test-email-template",
    "libexec/notifications/test-email-template"
) or die "Cannot copy file";
@output = map { s/\n$//; $_ }
  `utils/test_notifications hostproblem notifications/notify_by_email -t -e test-email-template 2>&1`;
is_deeply( \@output, $expected,
    "Email notification as expected for custom template" )
  || diag Data::Dump::dump(@output);
