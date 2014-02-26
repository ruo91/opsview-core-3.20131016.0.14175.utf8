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

# This package is for generic routines that are useful across Opsview
# This must be kept very light due to opsview.sh using this, so no non-core modules
# Use Opsview::Utils::* for utils that have dependencies
package Opsview::Utils;

use strict;
use warnings;
use Exporter;
use base qw/Exporter/;

our @EXPORT =
  qw(max_state max_state_text convert_state_to_text convert_host_state_to_text convert_to_arrayref);
our @EXPORT_OK =
  qw(merge_hashes escape_xml_data escape_xml convert_state_type_to_text convert_perl_regexp_to_js_string apidatatidy convert_uoms unique_objects set_highest_state set_highest_service_state get_ssh_version get_first_hash_key convert_text_to_state_type);

# This package is for utility functions that do not
# require the database

=item Opsview::Utils->make_shell_friendly( $string )

Will take $string and return back a single quoted version that can be run
in a shell

=cut

sub make_shell_friendly {
    my ( $class, $s ) = @_;

    # We use "'" to escape the quotes because Nagios has a special meaning for \, and does double escaping of this when used
    # as an argument to a check_command definition
    if ( defined $s ) {
        $s =~ s/'/'"'"'/g;
    }
    else {
        $s = "";
    }
    return "'" . $s . "'";
}

=item $escaped = Opsview::Utils->cleanup_args_for_nagios( $argument )

Takes $argument and escapes $$ for nagios.  Also calls C<escape_shriek> on
the argument to escape shrieks (exclamation marks).

=cut

sub cleanup_args_for_nagios {
    my ( $self, $text ) = @_;
    if ( defined $text ) {
        $text =~ s/\$/\$\$/g;
    }
    else {
        $text = '';
    }
    return $self->escape_shriek($text);
}

=item $escaped = Opsview::Utils->escape_shriek( $argument );

Escape any shrieks (exclamation marks) in the given $argument.  Already
escaped shrieks are left alone (i.e. ! becomes \!, \! is left alone).

=cut

sub escape_shriek {
    my ( $self, $text ) = @_;
    if ( defined($text) ) {
        $text =~ s/(?<!\\)\!/\\!/g;
    }
    else {
        $text = '';
    }
    return $text;
}

# TODO: Should look into using Nagios::Plugin
{
    my $default_order = [ 2, 1, 0, 3, 4 ];

    sub max_state {
        my ( $a, $b, $order ) = @_;

        for my $state ( @{ $order || $default_order } ) {
            return $state if $a == $state || $b == $state;
        }
    }
}

{
    my $default_order = [qw( critical warning ok unknown )];

    sub max_state_text {
        my ( $a, $b, $order ) = @_;

        for my $state ( @{ $order || $default_order } ) {
            return $state if $a eq $state || $b eq $state;
        }
    }
}

sub convert_state_to_text {
    my $s = shift;
    if    ( $s == 0 ) { return "ok" }
    elsif ( $s == 1 ) { return "warning" }
    elsif ( $s == 2 ) { return "critical" }
    elsif ( $s == 3 ) { return "unknown" }
    die "Invalid state: $s\n";
}

sub convert_host_state_to_text {
    my $s = shift;
    if    ( $s == 0 ) { return "up" }
    elsif ( $s == 1 ) { return "down" }
    elsif ( $s == 2 ) { return "unreachable" }
    die "Invalid state: $s\n";
}

my $state_type_lookup = {
    "0" => "soft",
    "1" => "hard",
};
my $state_type_lookup_reverse = { reverse %$state_type_lookup };

sub convert_state_type_to_text {
    my $s = shift;
    die "Missing state type" unless defined $s;
    $_ = $state_type_lookup->{$s};
    die "Invalid state type: $s" unless defined $_;
    return $_;
}

# Will return undef if input doesn't match any expected
sub convert_text_to_state_type {
    my $s = shift;
    die "Missing state type" unless defined $s;
    $s = lc($s);
    $_ = $state_type_lookup_reverse->{$s};
    return $_;
}

# Converts a scalar into an arrayref
sub convert_to_arrayref {
    my $array = shift;
    if ( defined $array ) {
        if ( ref $array eq "" ) {
            $array = [$array];
        }
    }
    else {
        $array = [];
    }
    return $array;
}

# Use this routine when there are multiple hash keys that do the same thing. Will
# return the first key value that exists. Otherwise returns undef
sub get_first_hash_key {
    my $hash = shift;
    while ( my $key = shift ) {
        if ( exists $hash->{$key} ) {
            return $hash->{$key};
        }
    }
    return undef;
}

sub escape_xml_data {
    my $xmlstr = shift;
    return $xmlstr
      if ( $xmlstr =~ /&(amp|lt|gt|apos|quot);/ )
      ; # Do not change if already encoded
    return escape_xml($xmlstr);
}

sub escape_xml {
    my $xmlstr = shift;
    $xmlstr =~ s/\&/\&amp;/g;
    $xmlstr =~ s/\>/\&gt;/g;
    $xmlstr =~ s/\</\&lt;/g;
    $xmlstr =~ s/\"/\&quot;/g;
    $xmlstr =~ s/\'/&apos;/g;
    $xmlstr;
}

sub convert_perl_regexp_to_js_string {
    my ($re) = @_;
    my $string = "$re";
    $string =~ s/\Q(?-xism://;
    $string =~ s/\Q(?^://;
    $string =~ s/\)$//;
    $string = "/" . $string . "/";
    $string;
}

# Recursive function to remove specified keys from hash
# Usage: Opsview::Utils->remove_keys_from_hash( $hash, ["ref"] )
# WARNING: Will change the references passed in
sub remove_keys_from_hash {
    my ( $class, $hash, $allowed_keys, $do_not_die_on_non_hash ) = @_;

    if ( ref $hash ne "HASH" ) {

        # Double negative as default is to die
        unless ($do_not_die_on_non_hash) {
            die "Not a HASH: $hash";
        }
        return $hash;
    }

    # We cache the keys_list into
    if ( !defined $allowed_keys ) {
        die "Must specify $allowed_keys";
    }

    # OK
    elsif ( ref $allowed_keys eq "HASH" ) {

    }
    elsif ( ref $allowed_keys eq "ARRAY" ) {
        my @temp = @$allowed_keys;
        $allowed_keys = {};
        map { $allowed_keys->{$_} = 1 } @temp;
    }
    elsif ( ref $allowed_keys ) {
        $allowed_keys = { $allowed_keys => 1 };
    }
    else {
        die "allowed_keys incorrect";
    }

    foreach my $k ( keys %$hash ) {
        if ( ref $hash->{$k} eq "ARRAY" ) {
            my @new_list;
            foreach my $item ( @{ $hash->{$k} } ) {
                push @new_list,
                  $class->remove_keys_from_hash( $item, $allowed_keys,
                    $do_not_die_on_non_hash );
            }
            $hash->{$k} = \@new_list;
        }
        elsif ( ref $hash->{$k} eq "HASH" ) {
            $hash->{$k} =
              $class->remove_keys_from_hash( $hash->{$k}, $allowed_keys,
                $do_not_die_on_non_hash );
        }
        elsif ( exists $allowed_keys->{$k} ) {
            delete $hash->{$k};
        }
    }
    return $hash;
}

# Recursive function to add "me." to front of all hash keys that look like columns for SQL::Abstract
# Stops as soon as you get to a possible column, and don't traverse further down (as these will be search params)
sub add_me_to_columns {
    my ( $class, $hash ) = @_;
    die "Not a HASH: $hash" if ( ref $hash ne "HASH" );
    foreach my $k ( keys %$hash ) {
        next unless defined $hash->{$k};
        if ( $k =~ /^\-/ ) {
            if ( ref $hash->{$k} eq "ARRAY" ) {
                my @new_list;
                foreach my $item ( @{ $hash->{$k} } ) {
                    push @new_list, $class->add_me_to_columns($item);
                }
                $hash->{$k} = \@new_list;
            }
            elsif ( ref $hash->{$k} eq "HASH" ) {
                $hash->{$k} = $class->add_me_to_columns( $hash->{$k} );
            }
        }
        else {
            $hash->{"me.$k"} = delete $hash->{$k};
        }
    }
    return $hash;
}

# Recursive function to convert all values to string
# Usage: Opsview::Utils->convert_all_values_to_string( $hash )
sub convert_all_values_to_string {
    my ( $class, $hash, $dt_formatter ) = @_;
    die "Not a HASH: $hash" if ( ref $hash ne "HASH" );

    $class->_convert_all_values_to_string_recursive( $hash, $dt_formatter );
}

sub _convert_all_values_to_string_recursive {
    my ( $class, $item, $dt_formatter ) = @_;

    my $ref = ref $item;
    if ( $ref eq "HASH" ) {
        foreach my $k ( keys %$item ) {
            next unless defined $item->{$k};
            $item->{$k} =
              $class->_convert_all_values_to_string_recursive( $item->{$k},
                $dt_formatter );
        }
    }
    elsif ( $ref eq "ARRAY" ) {
        my @new_list;
        foreach my $single (@$item) {
            push @new_list,
              $class->_convert_all_values_to_string_recursive( $single,
                $dt_formatter );
        }
        $item = \@new_list;
    }
    elsif ( $ref eq "DateTime" ) {

        # All datetime objects should serialize to epoch time to get a consistent UTC timezone
        # But if a dt_formatter is passed in, use that to format time values
        if ($dt_formatter) {
            $item = $dt_formatter->($item) . "";
        }
        else {
            $item = $item->epoch . "";
        }
    }

    # Simple scalars are stringified
    elsif ( $ref eq "" ) {
        $item = $item . "";
    }
    return $item;
}

my $uom_conversion = {
    "B" => {
        uom        => "bytes",
        multiplier => 1
    },
    "KB" => {
        uom        => "bytes",
        multiplier => 1000
    },
    "MB" => {
        uom        => "bytes",
        multiplier => 1000 * 1000
    },
    "TB" => {
        uom        => "bytes",
        multiplier => 1000 * 1000 * 1000
    },
    "s" => {
        uom        => "seconds",
        multiplier => 1
    },
    "ms" => {
        uom        => "seconds",
        multiplier => 1 / 1000
    },
    "us" => {
        uom        => "seconds",
        multiplier => 1 / 1000000
    },
    "%" => {
        uom        => "percent",
        multiplier => 1
    },
};

# We have a mapping file so you can have the different uom values referencing the same conversion
my $uom_mapping = {
    "B"  => "B",
    "KB" => "KB",
    "M"  => "MB", # nsclient returns back M for MB - grrrrr!
    "MB" => "MB",
    "TB" => "TB",
    "s"  => "s",
    "ms" => "ms",
    "us" => "us",
    "%"  => "%",
};

# Returns (uom_new, uom_multiplier) based on the UOM being passed
sub convert_uoms {
    my ($uom) = @_;
    my $new_uom = $uom || "";
    my $multiplier = 1;
    if ( my $mapped = $uom_mapping->{$uom} ) {
        if ( my $known_conversion = $uom_conversion->{$mapped} ) {
            $new_uom    = $known_conversion->{uom};
            $multiplier = $known_conversion->{multiplier};
        }
    }
    return ( $new_uom, $multiplier );
}

sub unique_objects {
    my ($list) = @_;
    my @uniq;
    my %seen;
    foreach $_ (@$list) {
        push @uniq, $_ unless $seen{ $_->id }++;
    }
    return @uniq;
}

# This takes the host state into account when calculating the highest state
sub set_highest_state {
    my ($hash) = @_;
    $hash->{computed_state} = set_highest_service_state( $hash->{services} );
    if (
            $hash->{computed_state} ne 'critical'
        and exists $hash->{hosts}->{down}
        and (
            (
                exists $hash->{hosts}->{down}->{handled}
                and $hash->{hosts}->{down}->{handled} > 0
            )
            or ( exists $hash->{hosts}->{down}->{unhandled}
                and $hash->{hosts}->{down}->{unhandled} > 0 )
        )
      )
    {
        $hash->{computed_state} = "critical";
    }
    if (
        # Don’t override a higher state than what we could be about to set it to.
        not grep { $_ eq $hash->{computed_state} } qw( critical warning )
        and exists $hash->{hosts}->{unreachable}
        and (
            (
                exists $hash->{hosts}->{unreachable}->{handled}
                and $hash->{hosts}->{unreachable}->{handled} > 0
            )
            or ( exists $hash->{hosts}->{unreachable}->{unhandled}
                and $hash->{hosts}->{unreachable}->{unhandled} > 0 )
        )
      )
    {
        $hash->{computed_state} = "unknown";
    }
}

sub set_highest_service_state {
    my ($hash) = @_;
    $hash->{computed_state} = "ok";
    foreach my $state (qw(critical warning unknown)) {
        if ( exists $hash->{$state} && $hash->{$state} > 0 ) {
            $hash->{computed_state} = $state;
            last;
        }
    }
    return $hash->{computed_state};
}

=item apidatatidy

Returns a beautified output. Will work out datatype

=cut

sub apidatatidy {
    my ($data) = @_;
    my $perl;
    {
        no warnings;
        $perl = eval $data;
    }
    if ( !$@ ) {
        require Data::Dump;
        $_ = Data::Dump::dump($perl);
        return $_;
    }

    require JSON::XS;
    my $j = JSON::XS->new->pretty->relaxed(1)->canonical(1);
    $perl = eval { $j->decode($data) };
    if ( !$@ ) {
        return $_ = $j->encode($perl);
    }

    # If we don't know what it is, just return it back
    return $data;
}

=item get_ssh_version

Determine the version number of ssh being used.  Put here to allow
for adequate testing of version strings

=cut

sub get_ssh_version {
    my ($ssh_version_string) = @_;
    if ( !$ssh_version_string ) {
        $ssh_version_string = qx/ssh -V 2>&1/;
    }

    my ($ssh_version) = $ssh_version_string =~ /^\w+SSH_(\d+\.\d+)/;

    $ssh_version ||= 0.0;

    return $ssh_version;
}

=item merge_hashes

copied from Catalyst::Utils::merge_hashes to avoid loading Class::MOP

=cut

#<<< skip perlitdy
sub merge_hashes {
    my ( $lefthash, $righthash ) = @_;

    return $lefthash unless defined $righthash;

    my %merged = %$lefthash;
    for my $key ( keys %$righthash ) {
        my $right_ref = ( ref $righthash->{ $key } || '' ) eq 'HASH';
        my $left_ref  = ( ( exists $lefthash->{ $key } && ref $lefthash->{ $key } ) || '' ) eq 'HASH';
        if( $right_ref and $left_ref ) {
            $merged{ $key } = merge_hashes(
                $lefthash->{ $key }, $righthash->{ $key }
            );
        }
        else {
            $merged{ $key } = $righthash->{ $key };
        }
    }

    return \%merged;
}
#>>> skip perlitdy

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
