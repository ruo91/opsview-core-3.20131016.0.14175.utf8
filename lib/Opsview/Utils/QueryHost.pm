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

# This must be light weight due to being used by check_snmp_interfaces_cascade
package Opsview::Utils::QueryHost;

use strict;
use warnings;

use Opsview::Run;
use Opsview::Utils qw(convert_to_arrayref);
use Opsview::Utils::SnmpInterfaces;

# Expects $args of:
#  command => "query_host" (optional, for testing purposes)
#  hostaddress => ip
#  hostobject  => object (if defined in Opsview)
#  snmp_version => 1, 2c or 3
#  snmp_port => port (defaults to 161)
#  monitoringserver => object, (if on slave)
#  snmp_auth => { community => "public" } or
#  snmp_auth => {
#    username     => "user",
#    authprotocol => "md5",
#    authpassword => "password",
#    privprotocol => "md5",
#    privprotocol => "password",
#  },
#  testconnection => 1,
# Returns:
# {
#   success => true, otherwise empty
#   command => \@command_with_args,
#   stderr => "stderr from query_host",
#   error => "error message",
#   warnings => [ "warnings" ],
#   output => raw output from query_host
#   data => hash of xml data,
#   parse_error => string of set error messages,
# }
sub run {
    my ( $class, $args ) = @_;
    my $opts = {
        command                     => "/usr/local/nagios/bin/query_host",
        default_throughput_critical => "50%",
        default_throughput_warning  => "",
        default_errors_critical     => 10,
        default_errors_warning      => "",
        default_discards_critical   => 15,
        default_discards_warning    => "",
        %$args,
    };
    die "Need host" unless exists $opts->{hostaddress};
    my $hostname  = $opts->{hostaddress};
    my $snmp_port = $opts->{snmp_port};

    my $lookup_interface_configuration = {};
    if ( $opts->{hostobject} ) {
        foreach my $i ( $opts->{hostobject}->snmpinterfaces ) {
            $lookup_interface_configuration->{ $i->interfacename } = $i;
        }
    }
    die "Need snmp_version"      unless exists $opts->{snmp_version};
    die "Need snmp_auth"         unless exists $opts->{snmp_auth};
    die "Need snmp_auth as hash" unless ref( $opts->{snmp_auth} ) eq "HASH";

    my $snmp_version = $opts->{snmp_version};
    my @args;
    push @args, "-p", $snmp_version;
    if ($snmp_port) {
        push @args, "-P", $snmp_port;
    }
    if ( $snmp_version eq "1" or $snmp_version eq "2c" ) {
        die "Need community" unless defined $opts->{snmp_auth}->{community};
        my $snmp_community = $opts->{snmp_auth}->{community};
        push @args, "-C", $snmp_community;
    }
    elsif ( $snmp_version eq "3" ) {
        die "Need username" unless exists $opts->{snmp_auth}->{username};
        die "Need authprotocol"
          unless exists $opts->{snmp_auth}->{authprotocol};
        die "Need authpassword"
          unless exists $opts->{snmp_auth}->{authpassword};
        push @args, "-u", $opts->{snmp_auth}->{username};
        push @args, "-a", $opts->{snmp_auth}->{authprotocol};
        push @args, "-A", $opts->{snmp_auth}->{authpassword};

        if ( $opts->{snmp_auth}->{privpassword} ) {
            push @args, "-x", $opts->{snmp_auth}->{privprotocol};
            push @args, "-X", $opts->{snmp_auth}->{privpassword};
        }
    }
    else {
        die "Invalid snmp_version: $snmp_version";
    }

    if ( $opts->{tidy_ifdescr_level} ) {
        push @args, "-l", $opts->{tidy_ifdescr_level};
    }

    if ( $opts->{snmp_max_msg_size} ) {
        push @args, "-m", $opts->{snmp_max_msg_size};
    }

    if ( $opts->{testconnection} ) {
        push @args, "-T";
    }

    my $response = {};

    # Need the array for ssh_command later
    my @cmd = ( $opts->{command}, "-q", "-t", "-H", $hostname, @args );

    if ( my $monitoringserver = $opts->{monitoringserver} ) {
        if ( $monitoringserver->is_slave ) {
            @cmd = $monitoringserver->nodes->first->ssh_command( \@cmd );
        }
    }

    $response->{command} = \@cmd;

    my ( $rc, $out, $err ) = Opsview::Run->run_command(@cmd);

    $err = $@ if ($@);

    if ($err) {

        # Error could come from $@ or from run_command which would be an array
        if ( ref $err eq "ARRAY" ) {
            $err = "@$err";
        }
        $response->{stderr} = $err;
        return $response;
    }

    if ( ref $out ne "ARRAY" ) {
        $response->{output} = undef;
        return $response;
    }

    my @output = @$out;

    # Don't know why, but return code from close always appears to give -1
    # I think I do - Catalyst run commands require SIG{CHLD} set to IGNORE
    #warn("Got rc=".$?);
    require XML::Simple;
    my $xs = XML::Simple->new( ForceArray => [qw(interface)] );
    my $xml = join( "", @output );
    $response->{output} = $xml;
    my $data;
    eval { $data = $xs->XMLin($xml) };
    if ($@) {
        $response->{parse_error} = "invalidXML";
        return $response;
    }

    # Could get errors or warnings from query_host xml
    if ( $data->{error} ) {
        my $errors = convert_to_arrayref( $data->{error} );
        $response->{error} = join( "; ", @$errors );
        return $response;
    }
    $response->{warnings} = [];
    if ( $data->{warning} ) {
        my $warns = convert_to_arrayref( $data->{warning} );
        $response->{warnings} = $warns;
    }

    # Will get a hash like:
    # { sysDescr => "system description",
    #   interface => {
    #     1 => { ifAlias => "", ifLink => "up", ifSpeed => "10Mb/s", ifStatus => "up", ifDescr => "lo" },
    #     2 => { ...}
    #     ...
    #   },
    # }
    my $sys_descr = $data->{host}->{sysDescr};
    if ( !defined $sys_descr ) {
        $response->{parse_error} = "incorrectOutput";
        return $response;
    }
    chomp $sys_descr;
    $response->{system_description} = $sys_descr;
    if ( $opts->{testconnection} ) {
        return $response;
    }

    my $sys_contact  = $data->{host}->{sysContact};
    my $sys_location = $data->{host}->{sysLocation};
    $response->{system_contact}  = $sys_contact;
    $response->{system_location} = $sys_location;

    my $r = [];
    my %duplicates;
    my @warnings;
    my $max_id = 0;
    my $interfaces = $data->{host}->{interface} || {};

    # Sorted by name then by interfaceid
    # Also, add the id into the hash
    my @sorted_hashes = map { $interfaces->{ $_->[1] } }
      sort { $a->[0] cmp $b->[0] || $a->[1] <=> $b->[1] }
      map { $interfaces->{$_}->{id} = $_; [ $interfaces->{$_}->{ifDescr}, $_ ] }
      ( keys %$interfaces );

    # Add the default line to the list of interfaces returned by query_host
    # Done here, because various setups below also apply
    unless ( $args->{ignore_default} ) {
        unshift(
            @sorted_hashes,
            {
                id      => 0,
                ifDescr => ""
            }
        );
    }

    # Loop once here to get the max interfaces and find out the duplicate names
    my %seen;
    foreach $_ (@sorted_hashes) {
        if ( $_->{id} > $max_id ) {
            $max_id = $_->{id};
        }
        $seen{ $_->{ifDescr} }++;
    }
    my $max_length = length $max_id;

    INTERFACE: foreach my $interface_hash (@sorted_hashes) {
        my ( $interfacename, $interfaceid ) =
          ( $interface_hash->{ifDescr}, $interface_hash->{id} );

        # interfaceid = 0 is default line
        if ( !$interfacename && $interfaceid ) {
            push @{ $response->{blank_interface_names} }, $interfaceid;
            next INTERFACE;
        }
        my %extra;

        # Duplicated devices have a generated interfacename which is saved to the db as normal
        # However, the shortname is saved as the actual interface name with the indexid
        # so that at nagconfgen time we know this is a special interface
        if ( $seen{$interfacename} >= 2 ) {
            my $normalised_indexid =
              sprintf( "%0${max_length}d", $interfaceid );
            $extra{indexid}            = $normalised_indexid;
            $extra{duplicatename}      = 1;
            $extra{shortinterfacename} = $interfacename;
            $interfacename = $interfacename . "-" . $normalised_indexid;
        }
        if ( my $i = $lookup_interface_configuration->{$interfacename} ) {
            $extra{active}              = $i->active;
            $extra{throughput_warning}  = $i->throughput_warning;
            $extra{throughput_critical} = $i->throughput_critical;
            $extra{errors_warning}      = $i->errors_warning;
            $extra{errors_critical}     = $i->errors_critical;
            $extra{discards_warning}    = $i->discards_warning;
            $extra{discards_critical}   = $i->discards_critical;
            $extra{shortinterfacename}  = $i->shortinterfacename;
        }

        # For non-default interfaces, not already saved in DB, set to blank to mean "inherit default"
        elsif ($interfaceid) {
            map { $extra{$_} = "" }
              qw(throughput_warning throughput_critical errors_warning errors_critical discards_warning discards_critical);
        }

        # For default thresholds. Leave others undefined
        else {
            $extra{$_} = $opts->{"default_$_"}
              for
              qw(throughput_critical throughput_warning errors_critical errors_warning discards_critical discards_warning);
        }

        push @$r,
          {
            id            => $interfaceid,
            interfacename => $interfacename,
            ifDescr       => $interfacename,
            ifAlias       => $interface_hash->{ifAlias},
            ifSpeed       => $interface_hash->{ifSpeed},
            ifLink        => $interface_hash->{ifLink},
            ifStatus      => $interface_hash->{ifStatus},
            %extra
          };
    }
    $response->{interfaces} = $r;
    $response->{success}    = 1;
    return $response;
}

=head2 tidy_interface_ifdescr

Shim to Opsview::Utils::SnmpInterface::tidy_interface_ifdescr

=cut

sub tidy_interface_ifdescr {
    shift;
    Opsview::Utils::SnmpInterfaces->tidy_interface_ifdescr(@_);
}

1;
