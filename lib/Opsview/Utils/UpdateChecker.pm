#
# AUTHORS:
#    Copyright (C) 2003-2013 Opsview Limited. All rights reserved
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

package Opsview::Utils::UpdateChecker;

use strict;
use warnings;

use version;
use Sys::Hostname;
use Socket;
use Digest::MD5 qw(md5_hex);
use LWP::UserAgent;

use Opsview;
use Opsview::Schema;
use Opsview::Reloadtime;
use Opsview::Systempreference;
use Runtime;

sub new {
    my ( $class, $opts ) = @_;
    my $obj = {
        hostname => "downloads.opsview.com",
        ua       => LWP::UserAgent->new,
    };
    return bless $obj, $class;
}

sub set_options {
    my ( $self, $opts ) = @_;
    $self->{opts} = {
        include_advanced_stats => 1,
        proxy                  => "",
        timeout                => 10,
        %$opts,
    };
    $self->{url} = "http://" . $self->{hostname} . "/updates";
}

sub collect_stats {
    my $self = shift;

    my $opsview_version = "unknown";

    my $os                    = "";
    my $local_opsview_version = "unknown";

    my $hostname = $self->{hostname};

    $local_opsview_version = Opsview::Config->opsview_version;

    # open db connections
    my $schema = Opsview::Schema->my_connect;

    # stats that require user permission
    my $dbh = Runtime->db_Main;
    my ($num_services) =
      $dbh->selectrow_array( "SELECT COUNT(*) FROM opsview_host_services" );
    $dbh->disconnect;

    open( BUILD_OS, "/usr/local/nagios/etc/opsview_build_os" );
    my $os_arch = <BUILD_OS>;
    close(BUILD_OS);
    my $arch = "";
    $os_arch =~ s/[\n\r]//g;
    ( $os, $arch ) = split( / /, $os_arch ); # ignore command line os

    my @result = split( /-/, $os );

    my $remote_opsview_db = 0;

    # See if any snmp trap service checks are assigned to hosts (directly or via template)
    my $snmptraps = 0;
    if (
        $schema->resultset("Servicechecks")
        ->search( { checktype => 4 }, { join => ["hostservicechecks"] } )
        ->count > 0
        || $schema->resultset("Servicechecks")->search(
            { checktype => 4 },
            {
                join => {
                    "hosttemplateservicechecks" =>
                      { "hosttemplateid" => "hosthosttemplates" }
                }
            }
        )->count > 0
      )
    {
        $snmptraps++;
    }

    # stats to send
    my %stats = (
        arch          => $arch,
        os            => $os,
        include_major => Opsview::Systempreference->updates_includemajor,
        version       => $local_opsview_version
    );

    if ( $self->{opts}->{include_advanced_stats} ) {

        my $hostname = Sys::Hostname::hostname();
        my $hosthash = md5_hex($hostname);

        my $num_hosts    = $schema->resultset("Hosts")->count();
        my $num_contacts = $schema->resultset("Contacts")->count();
        my $num_slaves   = $schema->resultset("Monitoringservers")->count() - 1;
        my $num_slavenodes =
          $schema->resultset("Monitoringclusternodes")->count();
        my $num_keywords = $schema->resultset("Keywords")->count();

        $dbh = Opsview->db_Main;
        my $num_logins = $dbh->selectrow_array(
            'SELECT COUNT(*) FROM auditlogs WHERE text LIKE "Successful login:%" AND datetime > CONVERT_TZ(NOW() - INTERVAL 1 DAY, @@session.time_zone,"+00:00")'
        );

        my $useragents = $dbh->selectcol_arrayref(
            "SELECT id FROM useragents WHERE last_update > NOW() - INTERVAL 1 MONTH"
        );
        $dbh->disconnect;

        my %advanced_stats = (
            uuid           => Opsview::Systempreference->uuid,
            hosthash       => uc($hosthash),
            num_hosts      => $num_hosts,
            num_services   => $num_services,
            num_slaves     => $num_slaves,
            num_slavenodes => $num_slavenodes,
            num_contacts   => $num_contacts,
            num_keywords   => $num_keywords,
            num_api        => $schema->resultset("ApiSessions")->search(
                {
                    one_time_token => 0,
                    accessed_at    => { ">" => time - 60 * 60 * 24 }
                }
              )->count,
            "user_agent[]"    => $useragents,
            instance_id       => Opsview::Config->opsview_instance_id,
            avg_reload        => Opsview::Reloadtime->average_duration,
            perl_version      => $],
            num_logins        => $num_logins,
            remote_opsview_db => $remote_opsview_db,
            snmptraps         => $snmptraps,
            odw               => 0,
        );

        # Add linux info
        if ( $^O eq "linux" ) {
            require Sys::Statistics::Linux;
            my $lxs = Sys::Statistics::Linux->new(
                loadavg  => 1,
                memstats => 1,
                sysinfo  => 1,
            );
            my $stat = $lxs->get;
            $advanced_stats{master_loadavg15} = $stat->{loadavg}->{avg_15};
            $advanced_stats{master_cpus}      = $stat->{sysinfo}->{tcpucount};
            $advanced_stats{master_memory} =
              int( $stat->{memstats}->{memtotal} / 1024 );
        }

        @stats{ keys %advanced_stats } = values %advanced_stats;

    }

    return ( $self->{stats} = \%stats );
}

sub stats { shift->{stats} }

sub post_stats {
    my $self = shift;

    # post back anonymised stats to opsview
    my $ua = $self->{ua};

    if ( $self->{opts}->{proxy} eq "" ) { $ua->env_proxy; }
    else { $ua->proxy( 'http', $self->{opts}->{proxy} ); }

    $ua->timeout( $self->{opts}->{timeout} );

    my $response = $self->{response} =
      $ua->post( $self->{url}, $self->{stats} );
}

sub code {
    shift->{response}->code;
}

sub is_success {
    shift->{response}->is_success;
}

sub content {
    shift->{response}->content;
}

sub message {
    shift->{response}->message;
}

sub result {
    my $self = shift;

    # decode response version
    my $return_code     = 1;
    my @lines           = split( /\n/, $self->{response}->content );
    my $opsview_version = $lines[0];
    my $additional_output;
    if ( $lines[1] && $lines[1] =~ m/^([0123]) ?(.*)?/ ) {
        $return_code       = $1;
        $additional_output = $2;
    }

    my $unknown_state_message = "";
    if ( $opsview_version eq "unknown" ) {
        $unknown_state_message =
            "Details for "
          . $self->{os} . "-"
          . $self->{arch}
          . " and package opsview not found at "
          . $self->{url};
    }

    # Check formats of version numbers, should be major.minor.point.svnver
    if ( !( $opsview_version =~ m/^([0-9]+\.){3}[0-9]+/ ) ) {
        $unknown_state_message =
            "Opsview version given on "
          . $self->{hostname}
          . " ($opsview_version) is not in a recognised format";
    }

    return $self->{result} = {
        new_version           => $opsview_version,
        return_code           => $return_code,
        additional_output     => $additional_output,
        unknown_state_message => $unknown_state_message,
    };

}

sub newer_version_available {
    my $self = shift;

    # Finally compare versions
    my $local_vers  = version->new( $self->{stats}->{version} );
    my $remote_vers = version->new( $self->{result}->{new_version} );

    return ( $local_vers < $remote_vers );
}

1;
