
#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

# Keep this module lightweight
package Opsview::Config;
use lib "/opt/opsview/perl/lib/perl5", "/usr/local/nagios/etc";
use strict;
no warnings 'once';
use Carp;

our $topdir = "/usr/local/nagios";
sub root_dir {$topdir}

sub web_root_dir {"/usr/local/opsview-web"}

sub upgrade_lock_file {"$topdir/var/upgrade.lock"}

{

    package Settings;
    use Carp;
    do "opsview.defaults" or croak( "Cannot read opsview.defaults: $!" );
    if ( -e ( $_ = "$Opsview::Config::topdir/etc/opsview.conf" ) ) {
        do $_
          or
          croak( "Cannot read $Opsview::Config::topdir/etc/opsview.conf: $!" );
    }
}

sub dragdrop_disabled {$Settings::dragdrop_disabled}

sub slave_initiated { $Settings::slave_initiated || 0 }

sub slave_base_port {
    $Settings::slave_base_port || croak "Must have a slave_base_port";
}

sub overrides { return $Settings::overrides }
sub logo_path { return $Settings::logo_path || '' }

sub use_https { return $Settings::use_https }
sub bind_address { return $Settings::bind_address || "0.0.0.0" }

sub authentication { return $Settings::authentication || "htpasswd" }

sub authtkt_shared_secret {
    return $Settings::authtkt_shared_secret
      || "b78b909e-7a1a-4a97-a9a6-6ee81d297fa1";
}
sub authtkt_domain { return $Settings::authtkt_domain || '' }

sub dbi      { return $Settings::dbi }
sub db       { return $Settings::db }
sub dbuser   { return $Settings::dbuser }
sub dbpasswd { return $Settings::dbpasswd }

sub runtime_dbi      { return $Settings::runtime_dbi }
sub runtime_db       { return $Settings::runtime_db }
sub runtime_dbuser   { return $Settings::runtime_dbuser }
sub runtime_dbpasswd { return $Settings::runtime_dbpasswd }

sub archive_retention_days {
    return
      defined $Settings::archive_retention_days
      ? $Settings::archive_retention_days
      : 180;
}

sub rrd_retention_days {
    return
      defined $Settings::rrd_retention_days
      ? $Settings::rrd_retention_days
      : 30;
}

sub opsview_instance_id { return $Settings::opsview_instance_id || 1 }

sub nagios_interval_length_in_seconds {
    return $Settings::nagios_interval_length_in_seconds;
}

sub nagios_interval_length {
    return shift->nagios_interval_length_in_seconds ? 1 : 60;
}

sub max_parallel_tasks {
    $_ = $Settings::max_parallel_tasks;
    if ( defined $_ ) {
        return $_ == 0 ? undef : $_;
    }
    else {
        return 4;
    }
}

sub backup_dir            { return $Settings::backup_dir }
sub backup_retention_days { return $Settings::backup_retention_days }

sub daily_backup { return $Settings::daily_backup }

=item Opsview::Config->backupfile( $reloadid )

Returns the full path to the backup file, based on the id

=cut

sub backupfile {
    my ( $class, $reloadid ) = @_;
    die "No reloadid" unless $reloadid;
    return $class->backup_dir . "/opsview-db-" . $reloadid . ".sql.gz";
}

sub nmis_maxthreads       { return $Settings::nmis_maxthreads }
sub report_retention_days { return $Settings::report_retention_days }
sub nmis_retention_days   { return $Settings::nmis_retention_days }

sub nsca_server_address    { return $Settings::nsca_server_address }
sub nsca_encryption_method { return $Settings::nsca_encryption_method }
sub nrd_shared_password    { return $Settings::nrd_shared_password }
sub slave_send_method      { return $Settings::slave_send_method }

sub graph_show_legend      { return $Settings::graph_show_legend }
sub graph_auto_max_metrics { return $Settings::graph_auto_max_metrics }

sub status_dat        { return $Settings::status_dat }
sub check_result_path { return $Settings::check_result_path }
sub object_cache_file { return $Settings::object_cache_file }
sub ndo_dat_file      { return $Settings::ndo_dat_file }

# A very quick method of working out Opsview version from opsview_web.yml file
sub opsview_version {
    my $v;
    open( YAML, "/usr/local/opsview-web/opsview_web.yml" )
      or die(
        "Cannot open /usr/local/opsview-web/opsview_web.yml to check local Opsview version"
      );
    while (<YAML>) {
        if (m/^build:/) {
            s/^[^0-9]*//;
            chomp;
            $v = $_;
            last;
        }
    }
    close YAML;
    $v;
}

sub dbic_options {
    return {
        RaiseError    => 1,
        AutoCommit    => 1,
        on_connect_do => ["SET time_zone = '+00:00'"]
    };
}

sub parse_attributes_regexp {
    return qr/%(([A-Z0-9_]+)(\:(\d))?)%/o;
}

sub mrtg_forks   { return $Settings::mrtg_forks }
sub mrtg_refresh { return $Settings::mrtg_refresh }

sub host_check_interval        { return $Settings::host_check_interval }
sub host_max_check_attempts    { return $Settings::host_max_check_attempts }
sub host_retry_interval        { return $Settings::host_retry_interval }
sub host_notification_interval { return $Settings::host_notification_interval }
sub host_flap_detection        { return $Settings::host_flap_detection }

sub service_check_interval     { return $Settings::service_check_interval }
sub service_max_check_attempts { return $Settings::service_max_check_attempts }
sub service_retry_interval     { return $Settings::service_retry_interval }
sub service_flap_detection     { return $Settings::service_flap_detection }
1;
