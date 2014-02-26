#
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
# This class holds functions that work across Class::DBI and DBIx::Class. Used
# during migration of the different models

package Opsview::HostBase;

use Carp;

=item $self->expand_host_macros( $command )

$command is expanded with possible host macros. These are currently supported:

 - $ADDRESSES$
 - $ADDRESSn$
 - $SNMP_VERSION$ (2c or 3)
 - $SNMP_COMMUNITY$
 - $SNMP_PORT$
 - $SNMPV3_USERNAME$
 - $SNMPV3_AUTHPROTOCOL$
 - $SNMPV3_AUTHPASSWORD$
 - $SNMPV3_PRIVPROTOCOL$
 - $SNMPV3_PRIVPASSWORD$

WARNING: $SNMP_COMMUNITY$ will be replaced with the community and include single quotes around it. This
is for the nagios configuration because it invokes the command in the shell and if the community includes 
a $ symbol, the community will be truncated

WARNING 2: If $SNMP_COMMUNITY$ has a single quote in it, then this will be changed to '\'' for the shell to
recognise (close outside quote, escape single quote, open next quote).

=cut

use Opsview::Utils;

sub expand_host_macros {
    my ( $self, $command ) = @_;
    if ( $command =~ /\$SNMP_COMMUNITY\$/ ) {
        $_ = Opsview::Utils->cleanup_args_for_nagios( $self->snmp_community );
        $_ = Opsview::Utils->make_shell_friendly($_);
        $command =~ s/\$SNMP_COMMUNITY\$/$_/g;
    }
    if ( $command =~ /\$ADDRESSES\$/ ) {
        $_ = $self->other_addresses
          or carp "Macro \$ADDRESSES\$ used, but no other addresses set for "
          . $self->name;
        s/ //g;
        $command =~ s/\$ADDRESSES\$/$_/g;
    }
    if ( $command =~ /\$ADDRESS\d\$/ ) {
        @_ = $self->other_addresses_array;
        for ( my $i = 0; $i < scalar @_; $i++ ) {
            $_ = $_[$i];
            s/ //g;
            my $j = $i + 1;
            $command =~ s/\$ADDRESS$j\$/$_/g;
        }

        # redefine any unchanged $ADDRESSx$ macros to primary ip address
        $command =~ s/(\$ADDRESS[\d]\$)/$self->ip/eg;
    }
    if ( $command =~ /\$SNMP_VERSION\$/ ) {
        $_ = $self->snmp_version;
        $command =~ s/\$SNMP_VERSION\$/$_/g;
    }
    if ( $command =~ /\$SNMP_PORT\$/ ) {
        $_ = $self->snmp_port;
        $command =~ s/\$SNMP_PORT\$/$_/g;
    }
    if ( $command =~ /\$SNMPV3_USERNAME\$/ ) {
        $_ = Opsview::Utils->cleanup_args_for_nagios( $self->snmpv3_username );
        $_ = Opsview::Utils->make_shell_friendly($_);
        $command =~ s/\$SNMPV3_USERNAME\$/$_/g;
    }
    if ( $command =~ /\$SNMPV3_AUTHPROTOCOL\$/ ) {
        $_ = $self->snmpv3_authprotocol;
        $command =~ s/\$SNMPV3_AUTHPROTOCOL\$/$_/g;
    }
    if ( $command =~ /\$SNMPV3_AUTHPASSWORD\$/ ) {
        $_ =
          Opsview::Utils->cleanup_args_for_nagios( $self->snmpv3_authpassword );
        $_ = Opsview::Utils->make_shell_friendly($_);
        $command =~ s/\$SNMPV3_AUTHPASSWORD\$/$_/g;
    }
    if ( $command =~ /\$SNMPV3_PRIVPROTOCOL\$/ ) {
        $_ = $self->snmpv3_privprotocol;
        $command =~ s/\$SNMPV3_PRIVPROTOCOL\$/$_/g;
    }
    if ( $command =~ /\$SNMPV3_PRIVPASSWORD\$/ ) {
        $_ =
          Opsview::Utils->cleanup_args_for_nagios( $self->snmpv3_privpassword );
        $_ = Opsview::Utils->make_shell_friendly($_);
        $command =~ s/\$SNMPV3_PRIVPASSWORD\$/$_/g;
    }
    return $command;
}

# Convenience function to return an array of other_addresses
sub other_addresses_array {
    ( my $other_ifs = shift->other_addresses ) =~ s/\s+//g;
    return split( ",", $other_ifs, -1 );
}

sub notifications_enabled {
    my $self = shift;
    if   ( $self->notification_options ) { return 1; }
    else                                 { return 0 }
}

sub runtime_host {
    my ($self) = @_;
    require Runtime::Host;
    return Runtime::Host->search( opsview_host_id => $self->id )->first;
}

1;
