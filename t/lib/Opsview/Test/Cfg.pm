package Opsview::Test::Cfg;

#
# Small module to pick up configured database named from opsview.conf
# just in case they have been changed
#

use strict;
use warnings;
use FindBin qw($Bin);

my $conf = '/usr/local/nagios/etc/opsview.conf';

my %config = (
    opsview => 'opsview',
    runtime => 'runtime',
    odw     => 'odw',
    reports => 'reports',

    opsview_passwd => 'changeme',
    runtime_passwd => 'changeme',
    odw_passwd     => 'changeme',
    reports_passwd => 'changeme',

    shared_secret => 'shared-secret-please-change',
    overrides     => '

',
);

sub import {
    my ( $self, %args ) = @_;

    if ( $args{conf} ) {
        $conf = $args{conf};
    }

    if ( -f $conf ) {

        # Turn off strict here just for reading the conf file else would have
        # to specify all the vars we would otherwise find in there
        no strict;
        eval { do $conf; };
        if ( !$@ ) {
            $config{opsview} = $db         if $db;
            $config{runtime} = $runtime_db if $runtime_db;
            $config{odw}     = $odw_db     if $odw_db;
            $config{reports} = $reports_db if $reports_db;

            $config{opsview_passwd} = $dbpasswd         if $dbpasswd;
            $config{runtime_passwd} = $runtime_dbpasswd if $runtime_dbpasswd;
            $config{odw_passwd}     = $odw_dbpasswd     if $odw_dbpasswd;
            $config{reports_passwd} = $reports_dbpasswd if $reports_dbpasswd;

            $config{shared_secret} = $authtkt_shared_secret
              if $authtkt_shared_secret;
            $config{overrides} = $overrides if $overrides;
        }
    }
}

sub opsview { return $config{opsview} }
sub runtime { return $config{runtime} }
sub odw     { return $config{odw} }
sub reports { return $config{reports} }

sub opsview_passwd { return $config{opsview_passwd} }
sub runtime_passwd { return $config{runtime_passwd} }
sub odw_passwd     { return $config{odw_passwd} }
sub reports_passwd { return $config{reports_passwd} }

sub shared_secret { return $config{shared_secret} }
sub overrides     { return $config{overrides} }

1;
