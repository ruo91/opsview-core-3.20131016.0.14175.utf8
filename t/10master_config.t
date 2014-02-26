#!/usr/bin/perl

use Test::More;
use Test::LongString;

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";

my %test_data = (
    root_dir               => '/usr/local/nagios',
    web_root_dir           => '/usr/local/opsview-web',
    upgrade_lock_file      => '/usr/local/nagios/var/upgrade.lock',
    logo_path              => '',
    nagios_interval_length => 60,
);

use Opsview::Test::Cfg;

my %setting_data = (
    dragdrop_disabled => undef,
    slave_initiated   => 0,
    slave_base_port   => 25800,

    use_https                         => 0,
    authentication                    => 'htpasswd',
    authtkt_shared_secret             => Opsview::Test::Cfg->shared_secret,
    authtkt_domain                    => '',
    dbi                               => 'dbi:mysql',
    db                                => Opsview::Test::Cfg->opsview,
    dbuser                            => 'opsview',
    dbpasswd                          => Opsview::Test::Cfg->opsview_passwd,
    runtime_dbi                       => 'dbi:mysql',
    runtime_db                        => Opsview::Test::Cfg->runtime,
    runtime_dbuser                    => 'nagios',
    runtime_dbpasswd                  => Opsview::Test::Cfg->runtime_passwd,
    archive_retention_days            => 180,
    rrd_retention_days                => 30,
    opsview_instance_id               => 1,
    nagios_interval_length_in_seconds => 0,
    max_parallel_tasks                => 4,
    backup_dir                        => '/usr/local/nagios/var/backups',
    backup_retention_days             => 30,
    daily_backup                      => 1,
    nsca_server_address               => "127.0.0.1",
    nrd_shared_password               => "initial",
    slave_send_method                 => "nrd",
    status_dat                        => '/usr/local/nagios/var/status.dat',
    mrtg_forks                        => 8,
    mrtg_refresh                      => 300,
    host_check_interval               => 5,
    host_max_check_attempts           => 2,
    host_retry_interval               => 1,
    host_notification_interval        => 60,
    host_flap_detection               => 1,
    service_check_interval            => 5,
    service_max_check_attempts        => 3,
    service_retry_interval            => 1,
    service_flap_detection            => 1,
);

my %strings_data = (
    overrides => '
# Uncomment next line to change pager/SMS number for Opsview administrator
# nagios_admin_pager=monitorman@company.com

# Uncomment next line to set maximum concurrent service checks, use this to tune performance settings
# nagios_max_concurrent_checks=50

# Uncomment next line to disable notifications (for system upgrades and maintenance)
# nagios_enable_notifications=0

# Uncomment next line to disable authentication for access to monitoring UI, use for debugging only
# cgi_use_authentication=0

# Uncomment next line to change refresh rate for Nagios monitoring screens
# cgi_refresh_rate=30

# Uncomment next line to enable logging of passive check results
# nagios_log_passive_checks=1

',
);

# Remove Hudson specific changes
if ( $ENV{OPSVIEW_TEST_HUDSON} ) {
    delete $strings_data{overrides};
}

plan tests => keys(%test_data) + ( keys(%setting_data) * 2 ) +
  keys(%strings_data) + 1;

use_ok( "Opsview::Config" );

foreach my $method ( keys(%test_data) ) {
    is( Opsview::Config->$method, $test_data{$method},
        "method $method is '$test_data{$method}'"
    );
}

foreach my $setting ( keys(%setting_data) ) {
    my $output_setting;
    if ( defined( $setting_data{$setting} ) ) {
        $output_setting = "'" . $setting_data{$setting} . "'";
    }
    else {
        $output_setting = 'undefined';
    }

    is( Opsview::Config->$setting, $setting_data{$setting},
        "method $setting is $output_setting"
    );

    my $variable = eval "\$Settings::$setting";

    is( $variable, $setting_data{$setting},
        "variable $setting is $output_setting"
    );
}

foreach my $string ( keys(%strings_data) ) {
    is_string( Opsview::Config->$string, $strings_data{$string},
        "$string setting correct"
    );
}
