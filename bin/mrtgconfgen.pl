#!/usr/bin/perl
#
#
# SYNTAX:
# 	mrtgconfgen.pl [full]
#
# DESCRIPTION:
#	If $1 = full, then will recreate mrtg configurations for all hosts,
#	even if nothing has changed
#
#	This now works autonomously
#   Removed slave support
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

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc", "$Bin/../perl/lib";
use Opsview;
use Opsview::Config;
use Opsview::Utils;
use Opsview::Reloadmessage;
use Opsview::Schema;
use File::Copy;
use Getopt::Std;
use Data::UUID;
use version;

umask 027;

# Don't allow cfgmaker to use Opsview provided perl libs as it may conflict
# with what mrtg has been compiled/set up with by the distro
$ENV{PERL5LIB} = undef;

$SIG{CHLD}    = 'IGNORE';
$SIG{__DIE__} = sub {
    return if ( $^S == 1 );
    Opsview::Reloadmessage->create(
        {
            utime    => time,
            message  => "@_",
            severity => "critical",
        }
    );
};

my $nagios_root        = "/usr/local/nagios";
my $varpath            = "$nagios_root/var";
my $mrtgcfg            = "$nagios_root/etc/mrtg.cfg";
my $imgpath            = "$nagios_root/share/mrtg";
my $rrdpath            = "$nagios_root/var/mrtg";
my $master_configs_dir = "$nagios_root/configs";

my $opts = {};
getopts( "hq", $opts ) or die( "Incorrect options\n" );
if ( $opts->{h} ) {
    print "
	$0 -h
	$0 [-q]

	Where
		-h                This help text
		-q                Show only warnings
";
    exit 1;
}

my $state = shift @ARGV || "onchange";

my $schema = Opsview::Schema->my_connect;

if ( $state ne "full" ) {
    exit unless check_for_changes();
}

print scalar localtime, " Starting", $/ unless ( $opts->{q} );

# OVS-1299 - check the version of mrtg to ensure > 2.15
my $use_snmp_v3 = 0;
{
    my $required_mrtg_version = version->parse( '2.15.0' );
    my $have_mrtg_version;
    my ($version) = qx!env LANG=C /usr/bin/mrtg! =~ m/mrtg-(\d+\.\d+\.\d+)/;
    $have_mrtg_version = version->parse($version);

    if ( $have_mrtg_version >= $required_mrtg_version ) {
        $use_snmp_v3 = 1;
    }
}

my %cfgmaker;
my %fh;
my @snmpv3_hosts;
foreach my $ms ( $schema->resultset("Monitoringservers")->find(1) ) {
    next unless $ms->is_active;
    my @communities;
    foreach my $host (
        $ms->monitors(
            {
                use_mrtg    => 1,
                enable_snmp => 1
            }
        )
      )
    {
        if ( $host->snmp_version ne "3" && !$host->snmp_community ) {
            Opsview::Reloadmessage->create(
                {
                    utime   => time,
                    message => "'MRTG Graphs' enabled for "
                      . $host->name
                      . " but no valid community string defined",
                    severity          => "warning",
                    monitoringcluster => $ms->id,
                }
            );
            next;
        }
        my $snmp_version = $host->snmp_version;
        if ( $snmp_version eq "1" ) {
            push(
                @communities,
                Opsview::Utils->make_shell_friendly(
                        $host->snmp_community . '@'
                      . $host->ip . ":"
                      . $host->snmp_port
                      . "::::$snmp_version"
                )
            );
        }
        elsif ( $snmp_version eq "2c" ) {
            $snmp_version = 2;
            push(
                @communities,
                Opsview::Utils->make_shell_friendly(
                        $host->snmp_community . '@'
                      . $host->ip . ":"
                      . $host->snmp_port
                      . "::::$snmp_version"
                )
            );
        }
        else {
            if ( !$use_snmp_v3 ) {
                push( @snmpv3_hosts, $host->name );
            }
            else {
                $snmp_version = 3;
                my $contextid = Data::UUID->new();
                my @config;
                push( @config, '--contextengineid ', $contextid->create_hex()
                );
                push(
                    @config,
                    '--username ',
                    Opsview::Utils->make_shell_friendly(
                        $host->snmpv3_username
                    )
                );
                push(
                    @config,
                    '--authprotocol',
                    Opsview::Utils->make_shell_friendly(
                        $host->snmpv3_authprotocol
                    )
                );
                push(
                    @config,
                    '--authpassword',
                    Opsview::Utils->make_shell_friendly(
                        $host->snmpv3_authpassword
                    )
                );
                if ( $host->snmpv3_privpassword ) {

                    # convert private protocols into something that cfgmaker can understand if necessary
                    my $privprotocol = Opsview::Utils->make_shell_friendly(
                        $host->snmpv3_privprotocol );
                    my $sanitised_privprotocol =
                        $privprotocol == 'aes128' ? 'aescfb128'
                      : $privprotocol == 'aes'    ? 'aescfb128'
                      :                             $privprotocol;
                    push( @config, '--privprotocol ', $sanitised_privprotocol );
                    push(
                        @config,
                        '--privpassword',
                        Opsview::Utils->make_shell_friendly(
                            $host->snmpv3_privpassword
                        )
                    );
                }
                push(
                    @config,
                    Opsview::Utils->make_shell_friendly(
                            $host->ip . ":"
                          . $host->snmp_port
                          . "::::$snmp_version"
                    )
                );

                push( @communities, @config );
            }
        }
    }

    my $num = scalar @communities;
    print scalar localtime,
      " Job start on " . $ms->name . " with $num communities", $/
      unless ( $opts->{q} );
    my @cmd = ( "sh" );
    my $pid = open( $fh{ $ms->id }, "|-", @cmd ) or die "Cannot exec cfgmaker";
    $cfgmaker{$pid} = $ms;
    if ($use_snmp_v3) {
        unshift( @communities, '--enablesnmpv3 ' );
    }
    my $mrtg_forks   = Opsview::Config->mrtg_forks;
    my $mrtg_refresh = Opsview::Config->mrtg_refresh;
    print { $fh{ $ms->id } } <<"EOF";
if test $num -gt 0 ; then
cfgmaker --output=$mrtgcfg --global 'Forks: $mrtg_forks' --global 'Refresh: $mrtg_refresh' --global 'HtmlDir: $imgpath' --global 'ImageDir: $imgpath' --global 'Options[_]: growright,bits' --global 'LogDir: $rrdpath' --global 'LogFormat: rrdtool' --global 'IconDir: /images/mrtg' @communities
else
> $mrtgcfg
fi
perl -i -pe 's/^(WorkDir:.*)/#\$1 # Patched by mrtgconfgen.pl/i' $mrtgcfg
chmod 0640 $mrtgcfg
chgrp nagcmd $mrtgcfg
test ! -d $imgpath && mkdir -m 0755 $imgpath
EOF

}

if (@snmpv3_hosts) {
    Opsview::Reloadmessage->create(
        {
            utime => time,
            message =>
              "MRTG needs to be version 2.15.0 or greater for 'MRTG Graphs' to use SNMPv3 on the following hosts: "
              . join( ' ', @snmpv3_hosts ),
            severity => "warning",
        }
    );
}

print scalar localtime, " mrtgconfgen finished, but jobs may still be running",
  $/
  unless ( $opts->{q} );
exit;

# If any host or hosttemplate with MRTG graphs specified is uncommitted, then run
# TODO: this will miss out hosts that have this perf mon removed. How to catch?
sub check_for_changes {
    return $schema->resultset("Hosts")->search(
        {
            use_mrtg    => 1,
            uncommitted => 1,
            enable_snmp => 1
        }
    )->count;
}
