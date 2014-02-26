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
package Opsview::Utils::SnmpInterfaces;

use strict;
use warnings;

use Math::BigInt;
use Nagios::Plugin;

=head2 tidy_interface_ifdescr

Func to remove common words from interface ifDescr strings.  Some interface
ifDescr's are > 52 chars such as

C<<Nortel Ethernet Routing Switch 5510-48T Module - Unit 1 Port 1>>

Remove some predefined 'common' words to reduce the length of the string
to keep the unique part, to hopefully reduce the astring to < 52 chars

Should be used by query_host and check_snmp_linkstatus to keep in sync
with name changes

NOTE: the words to be removed are governed by the provided level which is
set on a per host basis.  This is to ensure upgraded systems are not
affected by adding new words here

=cut

sub tidy_interface_ifdescr {
    my ( $class, $level, $ifdescr ) = @_;

    my @remove_words;

    if ( $level !~ /\D/ && $level > 0 ) {
        if ( $level >= 1 ) {
            push( @remove_words,
                'Nortel Ethernet',
                'Nortel', 'Routing', 'Module' );
        }
        if ( $level >= 3 ) {
            push( @remove_words,
                'PCI Express', 'Quad Port', 'Gigabit', 'Server', );
        }
        if ( $level >= 4 ) {
            push( @remove_words, 'Corrigent systems', ', , ' );
        }

        foreach my $word (@remove_words) {
            $ifdescr =~ s/$word//g;
        }

        # Remove any leading spaces
        $ifdescr =~ s/^\s+//;

        # Remove any trailing spaces
        if ( $level >= 2 ) {
            $ifdescr =~ s/\s+$//;
        }

        # Remove any duplicate spaces
        $ifdescr =~ s/\s+/ /g;
    }

    # Remove any nasty NUL characters
    $ifdescr =~ s/\x00//g;

    return $ifdescr;
}

=begin ifOperStatus information

From Net-SNMP's ifOperStatus:

The current operational state of the interface. The
testing(3) state indicates that no operational packets can
be passed. If ifAdminStatus is down(2) then ifOperStatus
should be down(2). If ifAdminStatus is changed to up(1)
then ifOperStatus should change to up(1) if the interface is
ready to transmit and receive network traffic; it should
change to dormant(5) if the interface is waiting for
external actions (such as a serial line waiting for an
incoming connection); it should remain in the down(2) state
if and only if there is a fault that prevents it from going
to the up(1) state; it should remain in the notPresent(6)
state if the interface has missing (typically, hardware)
components.

=cut

sub _convert_status {
    $_ = shift;
    if    ( $_ == 1 ) { return "up" }
    elsif ( $_ == 5 ) { return "up" }
    else              { return "down" }
}

sub _get_table_data {
    my ( $class, $s, $interfaces, $oid_name, $oid_base, $opts_in ) = @_;
    $opts_in ||= {};
    my $opts = {
        fallback_oid_base   => "",
        use_bigint          => 0,
        use_convert_status  => 0,
        strip_nulls         => 0,
        ignore_empty_tables => 0,
        %$opts_in,
    };
    my $already_fallen_back = 0;

    # This is to debug if you have issues with devices that do not handle bulk requests very well
    my @extra_get_table_args;
    my $hostnames_to_force_to_use_getnext = {};

    #warn("hostname = ".$s->hostname, " version = ".$s->version);
    # SNMPv1 = 0, SNMPv2 = 1, SNMPv3 = 3
    if (   ( $hostnames_to_force_to_use_getnext->{ $s->hostname } )
        && ( $s->version != 0 ) )
    {

        #warn("Setting maxreps to 1 - forces to use getnextrequest");
        @extra_get_table_args = ( -maxrepetitions => 1 );
    }
    my $table = $s->get_table(
        -baseoid => $oid_base,
        @extra_get_table_args
    );
    if ( !defined $table && $opts->{fallback_oid_base} ) {
        $table = $s->get_table(
            -baseoid => $opts->{fallback_oid_base},
            @extra_get_table_args
        );
        if ( $opts->{multiplier} && $opts->{fallback_multiplier} ) {
            $opts->{multiplier} = $opts->{fallback_multiplier};
        }
        $already_fallen_back++;
    }
    if ( my $errstr = $s->error ) {
        if ( ( $errstr =~ /The requested table is empty or does not exist/ )
            && $opts->{ignore_empty_tables} )
        {

            # Make an exception here as some tables may not be available
            return undef;
        }
        die( "$oid_name: $errstr\n" );
    }

    my $interface_by_id = {};
    foreach my $oid ( keys %$table ) {
        my ($interface_number) = ( $oid =~ /(\d+)$/ );
        $interface_by_id->{$interface_number} = $table->{$oid};
    }

    # Secondary fallback. Use this flag to determine whether to do the
    # fallback or not
    # The stragegy is a sub that defines whether to merge or not
    my $fallback_ignore_merge_strategy;
    if ( $opts->{fallback_oid_base} && !$already_fallen_back ) {

        # Some tables have a subset of the data for the interfaces,
        # such as the octetsIn, so we will need to use the fallback table if possible
        # and merge data
        if ( $opts->{expected_number_of_interfaces}
            && ( scalar keys %$table < $opts->{expected_number_of_interfaces} )
          )
        {

            # If already exists, use current value
            $fallback_ignore_merge_strategy = sub { exists $_[0]->{ $_[1] } };
        }

        # This forces fallback, only if the table value for an interface is zero
        elsif ( $opts->{fallback_any_interface_value_is_zero} ) {
            foreach my $oid ( keys %$table ) {
                if ( $table->{$oid} == 0 ) {

                    # If already exists, use current value if > 0
                    $fallback_ignore_merge_strategy =
                      sub { $_[0]->{ $_[1] } > 0 };
                    last;
                }
            }
        }

    }

    if ($fallback_ignore_merge_strategy) {

        # Get data from fall back table
        $table = $s->get_table( -baseoid => $opts->{fallback_oid_base} );
        if ( my $errstr = $s->error ) {
            die( "Error on fallback table for $oid_name: $errstr\n" );
        }

        # Gather data and merge only if not already found
        foreach my $oid ( keys %$table ) {
            my ($interface_number) = ( $oid =~ /(\d+)$/ );

            next
              if $fallback_ignore_merge_strategy->(
                $interface_by_id, $interface_number
              );

            my $value = $table->{$oid};
            if ( $opts->{fallback_multiplier} ) {

                # Seems a bit silly, but we need to divide by the multiplier, otherwise
                # it gets scaled again below
                $value =
                    $value
                  * $opts->{fallback_multiplier}
                  / ( $opts->{multiplier} || 1 );
            }
            $interface_by_id->{$interface_number} = $value;
        }
    }

    foreach my $int ( keys %$interface_by_id ) {
        my $data = $interface_by_id->{$int};
        if ( $opts->{strip_nulls} ) {
            $data =~ s/\x00//g;
        }
        if ( $opts->{tidy_ifdescr_level} ) {
            $data =
              $class->tidy_interface_ifdescr( $opts->{tidy_ifdescr_level},
                $data );
        }
        if ( $opts->{use_convert_status} ) {
            $data = _convert_status($data);
        }
        if ( $opts->{multiplier} ) {
            $data = $data * $opts->{multiplier};
        }
        if ( $opts->{use_bigint} ) {
            $data = Math::BigInt->new($data);
        }

        $interfaces->{$int}->{$oid_name} = $data;
    }

    return 1;
}

# Returns a hash of interface information, indexed by index id
# Will die() if $s has unexpected errors
sub get_interface_information {
    my ( $class, $s, $opts_in ) = @_;
    $opts_in ||= {};
    my $opts = {
        tidy_ifdescr_level => 0,
        %$opts_in,
    };

    my $table;
    my $speed_multiplier = 1;
    my $interfaces       = {};
    my $result           = {
        interfaces => $interfaces,
        info       => []
    };

    my $ifEntry  = ".1.3.6.1.2.1.2.2.1";
    my $ifXEntry = ".1.3.6.1.2.1.31.1.1.1";

    # Interface link operational status
    # We need at least 1 table to get data in order to work out
    # the number of interfaces available
    $class->_get_table_data(
        $s, $interfaces,
        "ifOperStatus" => "$ifEntry.8",
        { use_convert_status => 1 },
    );

    my $number_of_interfaces = scalar keys %$interfaces;

    # We do the bandwidth retrieve first, so that the time is as close
    # as possible to the start of this function
    if ( $opts->{extra_stats} ) {

        # Bandwidth in
        $class->_get_table_data(
            $s,
            $interfaces,
            "octetsIn" => "$ifXEntry.6",
            {
                use_bigint                    => 1,
                fallback_oid_base             => "$ifEntry.10",
                expected_number_of_interfaces => $number_of_interfaces
            },
        );

        # Bandwidth out
        $class->_get_table_data(
            $s,
            $interfaces,
            "octetsOut" => "$ifXEntry.10",
            {
                use_bigint                    => 1,
                fallback_oid_base             => "$ifEntry.16",
                expected_number_of_interfaces => $number_of_interfaces
            },
        );

        # Errors in
        $class->_get_table_data(
            $s, $interfaces,
            "errorsIn" => "$ifEntry.14",
            { use_bigint => 1 },
        );

        # Errors out
        $class->_get_table_data(
            $s, $interfaces,
            "errorsOut" => "$ifEntry.20",
            { use_bigint => 1 },
        );

        # Discards in
        $class->_get_table_data(
            $s, $interfaces,
            "discardsIn" => "$ifEntry.13",
            { use_bigint => 1 },
        );

        # Discards out
        $class->_get_table_data(
            $s, $interfaces,
            "discardsOut" => "$ifEntry.19",
            { use_bigint => 1 },
        );
    }

    # Interface description. Should be on all systems
    $class->_get_table_data(
        $s,
        $interfaces,
        "ifDescr" => "$ifEntry.2",
        {
            tidy_ifdescr_level => $opts->{tidy_ifdescr_level},
            strip_nulls        => 1
        },
    );

    # Interface speeds (try high speed value first, to support > 4Gb interfaces)
    $class->_get_table_data(
        $s,
        $interfaces,
        "ifSpeed" => "$ifXEntry.15",
        {
            use_bigint                           => 1,
            multiplier                           => 1000000,
            fallback_oid_base                    => "$ifEntry.5",
            fallback_multiplier                  => 1,
            fallback_any_interface_value_is_zero => 1,
        },
    );

    # Interface link admin status
    $class->_get_table_data(
        $s, $interfaces,
        "ifAdminStatus" => "$ifEntry.7",
        { use_convert_status => 1 },
    );

    # TODO: This from check_snmp_linkstatus:
    # $ifAlias = "" if ( $ifAlias eq "-1" or $ifAlias eq "noSuchObject" );
    # Is this required?
    # Interface Alias information. May not be on some devices
    $class->_get_table_data(
        $s,
        $interfaces,
        "ifAlias" => "$ifXEntry.18",
        {
            strip_nulls         => 1,
            ignore_empty_tables => 1
        },
    );

    # Interface Name information. May not be on some devices
    $class->_get_table_data(
        $s,
        $interfaces,
        "ifName" => "$ifXEntry.1",
        {
            strip_nulls         => 1,
            ignore_empty_tables => 1
        },
    );

    return $result unless ( $opts->{extended_throughput_data} );

    my $table_exists;

    # Unicast In
    # We check if this table exists, because if it doesn't then the device
    # probably doesn't support extended throughput data
    # We just set an informational message and then continue
    $table_exists = $class->_get_table_data(
        $s,
        $interfaces,
        "unicastIn" => "$ifEntry.11",
        {
            use_bigint          => 1,
            ignore_empty_tables => 1
        },
    );
    if ( !$table_exists ) {
        push @{ $result->{info} },
          "No extended throughput data on device - will assume disabled";
        return $result;
    }

    # Unicast Out
    $class->_get_table_data(
        $s, $interfaces,
        "unicastOut" => "$ifEntry.17",
        { use_bigint => 1 },
    );

    # Multicast In
    $table_exists = $class->_get_table_data(
        $s,
        $interfaces,
        "multicastIn" => "$ifXEntry.8",
        {
            use_bigint                    => 1,
            fallback_oid_base             => "$ifXEntry.2",
            expected_number_of_interfaces => $number_of_interfaces,
            ignore_empty_tables           => 1
        },
    );

    # If we can't get separated data, we will use the IF-MIB non unicast data instead
    if ( !$table_exists ) {

        # Non-unicast In
        $class->_get_table_data(
            $s, $interfaces,
            "nonunicastIn" => "$ifEntry.12",
            { use_bigint => 1 },
        );

        # Non-unicast Out
        $class->_get_table_data(
            $s, $interfaces,
            "nonunicastOut" => "$ifEntry.18",
            { use_bigint => 1 },
        );

    }
    else {

        # Multicast Out
        $class->_get_table_data(
            $s,
            $interfaces,
            "multicastOut" => "$ifXEntry.12",
            {
                use_bigint                    => 1,
                fallback_oid_base             => "$ifXEntry.4",
                expected_number_of_interfaces => $number_of_interfaces
            },
        );

        # Broadcast In
        $class->_get_table_data(
            $s,
            $interfaces,
            "broadcastIn" => "$ifXEntry.9",
            {
                use_bigint                    => 1,
                fallback_oid_base             => "$ifXEntry.3",
                expected_number_of_interfaces => $number_of_interfaces
            },
        );

        # Broadcast Out
        $class->_get_table_data(
            $s,
            $interfaces,
            "broadcastOut" => "$ifXEntry.13",
            {
                use_bigint                    => 1,
                fallback_oid_base             => "$ifXEntry.5",
                expected_number_of_interfaces => $number_of_interfaces
            },
        );
    }

    return $result;
}

sub throughput_state {

    my (
        $warning_syntax, $critical_syntax,   $throughput_in,
        $throughput_out, $throughput_in_pct, $throughput_out_pct
    ) = @_;

    my $np = Nagios::Plugin->new;

    my ( $warning_state, $warning_speed_is_zero ) =
      _calculate_state( $np, 'warning', $warning_syntax,
        $throughput_in_pct, $throughput_out_pct, $throughput_in,
        $throughput_out );

    my ( $critical_state, $critical_speed_is_zero ) =
      _calculate_state( $np, 'critical', $critical_syntax,
        $throughput_in_pct, $throughput_out_pct, $throughput_in,
        $throughput_out );

    if ( $warning_speed_is_zero or $critical_speed_is_zero ) {
        return ( 1, 1 );
    }

    return
        $critical_state ? ( $critical_state, 0 )
      : $warning_state  ? ( $warning_state,  0 )
      :                   ( 0, 0 );

}

sub _calculate_state {

    my ( $np, $type, $criteria,
        $throughput_in_pct, $throughput_out_pct, $throughput_in,
        $throughput_out )
      = @_;
    $criteria = lc $criteria;

    my ( $input, $conjunction, $output );
    if ( $criteria =~ /^\s*in\s+([.\d:%]+)\s+(and|or)\s+out\s+([.\d:%]+)\s*$/ )
    {
        ( $input, $conjunction, $output ) = ( $1, $2, $3 );
    }
    elsif ( $criteria =~ /^\s*in\s+([.\d:%]+)\s*$/ ) {
        $input       = $1;
        $conjunction = 'or';
    }
    elsif ( $criteria =~ /^\s*out\s+([.\d:%]+)\s*$/ ) {
        $output      = $1;
        $conjunction = 'or';
    }
    elsif ( $criteria =~ /^\s*([.\d:%]+)\s*$/ ) {
        $input = $output = $1;
        $conjunction = 'or';
    }
    $input  =~ s/%+//g if defined $input;
    $output =~ s/%+//g if defined $output;

    my ( $max_state, $speed_is_zero ) = ( 0, 0 );

    if ( $criteria =~ /%/ ) {
        if (
            $conjunction eq 'and'
            and (   not defined $throughput_in_pct
                and not defined $throughput_out_pct )
          )
        {
            $speed_is_zero = 1;
            return ( 1, 1 );
        }
        elsif (
            $conjunction eq 'or'
            and (  not defined $throughput_in_pct
                or not defined $throughput_out_pct )
          )
        {
            $speed_is_zero = 1;
            return ( 1, 1 );
        }
    }

    # If we're only checking input.
    if ( not defined $output
        or ( $criteria =~ /%/ and not defined $throughput_out_pct ) )
    {
        $max_state = $np->check_threshold(
            check => ( $criteria =~ /%/ ? $throughput_in_pct : $throughput_in ),
            warning  => ( $type eq 'warning'  ? $input : undef ),
            critical => ( $type eq 'critical' ? $input : undef ),
        );
    }

    # If we're only checking output.
    elsif ( not defined $input
        or ( $criteria =~ /%/ and not defined $throughput_in_pct ) )
    {
        $max_state = $np->check_threshold(
            check =>
              ( $criteria =~ /%/ ? $throughput_out_pct : $throughput_out ),
            warning  => ( $type eq 'warning'  ? $output : undef ),
            critical => ( $type eq 'critical' ? $output : undef ),
        );
    }

    # We're checking everything.
    elsif (
        defined $input and defined $output
        or (    defined $throughput_in_pct
            and defined $throughput_out_pct )
      )
    {

        my $max_state_input = $np->check_threshold(
            check => ( $criteria =~ /%/ ? $throughput_in_pct : $throughput_in ),
            warning  => ( $type eq 'warning'  ? $input : undef ),
            critical => ( $type eq 'critical' ? $input : undef ),
        );

        my $max_state_output = $np->check_threshold(
            check =>
              ( $criteria =~ /%/ ? $throughput_out_pct : $throughput_out ),
            warning  => ( $type eq 'warning'  ? $output : undef ),
            critical => ( $type eq 'critical' ? $output : undef ),
        );

        if ( $conjunction eq 'and' ) {
            if ( $max_state_input and $max_state_output ) {
                $max_state =
                    $max_state_input > $max_state_output
                  ? $max_state_input
                  : $max_state_output;
            }
        }
        elsif ( $conjunction eq 'or' ) {
            if ( $max_state_input or $max_state_output ) {
                $max_state =
                  $max_state_input ? $max_state_input : $max_state_output;
            }
        }

    }
    else {
        # A catch-all. We shouldn't get here, but if Nagios returns no data...
        $speed_is_zero = 1;
    }

    return ( $max_state, $speed_is_zero );
}

1;
