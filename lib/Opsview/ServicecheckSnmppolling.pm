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

package Opsview::ServicecheckSnmppolling;
use base qw/Opsview/;

use strict;
our $VERSION = '$Revision: 1929 $';

__PACKAGE__->table( "servicechecksnmppolling" );

__PACKAGE__->columns( Primary => qw/id/, );
__PACKAGE__->columns( Essential =>
      qw/oid critical_comparison critical_value warning_comparison warning_value label calculate_rate/,
);

__PACKAGE__->constrain_column_regexp(
    label => q{/^[\w]{0,40}$/} => "invalidCharacters" );

# this is probably bad because plugin syntax is held in the model
# Returns the args
sub check_snmp_threshold_args {
    my $self = shift;
    my @args;
    if ( $self->critical_comparison eq "eq" ) {
        push @args, "-s '" . $self->critical_value . "' --invert-search";
    }
    elsif ( $self->critical_comparison eq "ne" ) {
        push @args, "-s '" . $self->critical_value . "'";
    }
    elsif ( $self->critical_comparison eq "regex" ) {
        push @args, "-r '" . $self->critical_value . "'";
    }
    elsif ( defined $self->critical_value ) {
        if ( $self->critical_comparison eq "==" ) {
            push @args,
              "-c " . $self->critical_value . ":" . $self->critical_value;
        }
        elsif ( $self->critical_comparison eq "<" ) {
            push @args, "-c " . $self->critical_value . ":";
        }
        elsif ( $self->critical_comparison eq ">" ) {
            push @args, "-c :" . $self->critical_value;
        }
    }
    if ( defined $self->warning_value ) {
        if ( $self->warning_comparison eq "==" ) {
            push @args,
              "-w " . $self->warning_value . ":" . $self->warning_value;
        }
        elsif ( $self->warning_comparison eq "<" ) {
            push @args, "-w " . $self->warning_value . ":";
        }
        elsif ( $self->warning_comparison eq ">" ) {
            push @args, "-w :" . $self->warning_value;
        }
    }
    return join( " ", @args );
}

1;
