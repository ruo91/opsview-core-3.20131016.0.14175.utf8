# Inspired by Nagios::Plugin::SNMP, but with much reduced option set
package Opsview::NagiosPlugin::SNMP;

use warnings;
use strict;

use Exporter;
use base qw(Exporter Nagios::Plugin);

use Net::SNMP;

#  Have to copy, inheritence doesn't work for these
use constant OK       => 0;
use constant WARNING  => 1;
use constant CRITICAL => 2;
use constant UNKNOWN  => 3;

our @EXPORT = qw(OK WARNING CRITICAL UNKNOWN);

our $VERSION = '1.0';

our $SNMP_USAGE = <<EOF;

-H,--hostname=HOST -p,--port=INT -v,--snmp-version=1|2c|3 
-C,--rocommunity=S 
-u,--auth-username=S -P,--auth-password=S -a,--auth-protocol=S -e,--priv-protocol=S -x,--priv-password=S
EOF

sub new {
    my $class = shift;
    my %args  = @_;

    # Not sure this should be set as it confuses
    #$args{'usage'} .= $SNMP_USAGE;

    $args{license}
      ||= "Copyright (C) 2003-2013 Opsview Limited. All rights reserved
This program is free software; you can redistribute it or modify
it under the terms of the GNU General Public License
";

    my $snmp_args = {
        "snmp-version"                => "2c",
        "snmp-check-oid"              => ".1.3.6.1.2.1.1.1.0", # sysDescr
        "snmp-agent-failure-critical" => 0,
        %{ delete $args{snmp} || {} },
    };

    my $self = $class->SUPER::new(%args);

    #  Add standard SNMP options to the plugin
    $self->_snmp_add_options( $self->{snmp_args} = $snmp_args );

    return $self;
}

#  Add Nagios::Plugin options related to SNMP to the plugin

sub _snmp_add_options {
    my ( $self, $defaults ) = @_;

    $self->add_arg(
        'spec'     => 'hostname|H=s',
        'help'     => "-H, --hostname HOSTNAME\n   Host to check HOSTNAME",
        'required' => 1
    );

    # We have to support -v for snmp_version, so this will override Nagios::Plugin's -v options
    $self->add_arg(
        'spec' => 'snmp-version|v=s',
        'help' =>
          "-v, --snmp-version 1|2c|3 [default 2c]\n   Select appropriate SNMP version. Disables --verbose",
        'default' => $defaults->{"snmp-version"},
    );

    $self->add_arg(
        'spec' => 'rocommunity|C=s',
        'help' =>
          "-C, --rocommunity NAME\n   Community string. SNMP v1|2c only. Defaults to 'public'",
        'default' => 'public'
    );

    $self->add_arg(
        'spec' => 'auth-username|U=s',
        'help' =>
          "-U, --auth-username USERNAME\n   Auth username. SNMP v3 only",
        default => '',
    );

    $self->add_arg(
        'spec' => 'auth-password|P=s',
        'help' => "-P, --auth-password PASSWORD\n   Auth password. SNMPv3 only",
        default => '',
    );

    $self->add_arg(
        'spec' => 'auth-protocol|a=s',
        'help' => "-a, --auth-protocol PROTO\n"
          . "   Auth protocol. SNMPv3 only. Default md5",
        'default' => 'md5'
    );

    $self->add_arg(
        'spec' => 'priv-password|x=s',
        'help' => "-x, --priv-password PASSWORD\n"
          . "   Priv password. SNMPv3 only",
        'default' => ''
    );

    $self->add_arg(
        'spec' => 'priv-protocol|e=s',
        'help' => "-e, --priv-protocol PROTO\n"
          . "   Priv protocol. SNMPv3 only. Default des",
        'default' => 'des'
    );

    $self->add_arg(
        'spec'    => 'port|p=s',
        'help'    => "-p, --port INT\n   SNMP agent port. Default 161",
        'default' => '161'
    );

    my $snmp_timeout = $defaults->{"snmp-timeout"}
      || ( ( $self->opts->{timeout} || 10 ) - 1 );
    $self->add_arg(
        'spec' => 'snmp-timeout|T=s',
        'help' =>
          "-T, --snmp-timeout INT\n   SNMP timeout. Defaults to plugin timeout - 1 second",
        'default' => $snmp_timeout,
    );
}

=head3 _snmp_validate_opts() - Validate passed in SNMP options

This method validates that any options passed to the plugin using
this library make sense.  Rules:

=over 4

 * If SNMP is version 1 or 2c, rocommunity must be set
 * If SNMP is version 3, auth-username and auth-password must be set

=back

=cut

sub _snmp_validate_opts {

    my $self = shift;

    my $opts = $self->opts;

    my $version = $opts->get( 'snmp-version' );
    if ( $version eq '3' ) {

        my @errors;

        for my $p (qw(auth-username auth-password auth-protocol)) {
            push( @errors, $p ) unless $opts->get($p);
        }

        $self->die( "SNMP parameter validation failed.  Missing: "
              . join( ', ', @errors ) )
          if scalar(@errors) > 0;

    }
    elsif ( $version eq "2c" || $version eq "1" ) {
        $self->die("SNMP parameter validation failed. Missing rocommunity!")
          if $opts->get('rocommunity') eq '';
    }
    else {
        $self->die( "Bad version: $version" );
    }

    return 1;

}

#Makes connection and returns the Net::SNMP object
# Can take overrides, eg:
# $snmp = $np->snmp( { rocommunity => "public@192.168.1.1" } );
sub snmp {
    my ( $self, $overrides ) = @_;

    my $undef_on_failure = $overrides->{undef_on_failure} || 0;

    my $opts = $self->opts;

    my $version = $opts->get( 'snmp-version' );

    my $hostname = $overrides->{hostname} || $opts->get( 'hostname' );

    my @args = (
        '-hostname' => $hostname,
        '-port'     => $opts->get('port'),
        '-timeout'  => $opts->get('snmp-timeout'),
    );

    push @args, '-domain' => $overrides->{domain}
      if exists $overrides->{domain};

    if ( $version eq '3' ) {
        push(
            @args,
            '-username'     => $opts->get('auth-username'),
            '-authpassword' => $opts->get('auth-password'),
            '-authprotocol' => $opts->get('auth-protocol'),
            '-privprotocol' => $opts->get('priv-protocol')
        );

        # privacy password cannot be empty
        my $privpass = $opts->get( 'priv-password' );
        if ( defined $privpass && length $privpass ) {
            push @args, '-privpassword' => $privpass;
        }
    }
    else {
        push( @args,
            '-community' => $overrides->{rocommunity}
              || $opts->get('rocommunity') );
    }

    my ( $session, $error ) = Net::SNMP->session( "-version", $version, @args );

    if ( $error ne '' ) {
        if ($undef_on_failure) {
            return undef;
        }
        $self->die( "Net-SNMP session creation failed: $error" );
    }

    if ( $version eq "2c" && $self->{snmp_args}->{"v1-fallback"} ) {
        if (
            !defined $session->get_request(
                $self->{snmp_args}->{"snmp-check-oid"} ) )
        {

            ( $session, $error ) = Net::SNMP->session( "-version", "1", @args );
            if ( $error ne '' ) {
                if ($undef_on_failure) {
                    return undef;
                }
                $self->die( "Net-SNMP session creation failed: $error" );
            }

            if (
                !defined $session->get_request(
                    $self->{snmp_args}->{"snmp-check-oid"} ) )
            {
                my $status = UNKNOWN;
                if ( $self->{snmp_args}->{"snmp-agent-failure-critical"} ) {
                    $status = CRITICAL;
                }
                $self->nagios_die( $status,
                    "Agent not responding, tried SNMP v1 and v2c"
                );
            }
        }
    }

    return $session;
}

sub getopts {
    my $self = shift;
    $self->SUPER::getopts();
    $self->_snmp_validate_opts();
}

1;
