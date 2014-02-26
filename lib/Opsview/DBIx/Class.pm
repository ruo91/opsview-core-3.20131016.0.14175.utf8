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

# This file is to hold all common row level methods

package Opsview::DBIx::Class;

use strict;
use warnings;
use Opsview::Config;
use Opsview::Auditlog;
use Opsview::Utils qw(convert_to_arrayref);

use base qw/DBIx::Class/;

sub opsviewdb {
    Opsview::Config->db;
}

sub my_delete {
    my ( $self, $info ) = @_;
    my $username        = $info->{username} || die "No username specified";
    my $identity_string = $self->identity_string;
    my $type            = $self->my_type_is;
    $self->delete();
    Opsview::Auditlog->create(
        {
            username => $username,
            text     => "Deleting $type: $identity_string"
        }
    );
}

sub class_title {
    my ($self) = @_;
    my $class_string = ref $self;
    $class_string =~ s/.*:://g;
    $class_string = lc($class_string);
    $class_string;
}

sub identity_string {
    my $self = shift;
    "id=" . $self->id . " name=" . $self->name;
}

# Looks up variable in joining table
sub variable {
    my ( $self, $name ) = @_;
    my $variable = $self->variables->find( { name => $name } );
    if ($variable) {
        return $variable->value;
    }
    return undef;
}

# Sets variable in joining table
sub set_variable {
    my ( $self, $name, $newval ) = @_;
    my $variable = $self->variables->find_or_create( { name => $name } );
    if ($variable) {
        if ( defined $newval ) {
            $variable->update( { value => $newval } );
        }
        return $variable->value;
    }
    return undef;
}

# Returns a hash of all variables
sub variables_hash {
    my ($self) = @_;
    my $vars = { map { $_->name => $_->value } ( $self->variables ) };
    return $vars;
}

# Compatibility with Opsview::*.pm
*my_web_type = \&my_type_is;

sub my_type_is {
    my ($self) = @_;

    # get type from class name and lower case
    my $class = ref($self) || $self;
    my $moniker = lc( ( split( '::', $class ) )[-1] );

    # also have to drop any plurals
    $moniker =~ s/s$//xsm;
    return $moniker;
}

# Helper function to find if anything is related. Used by timeperiods
sub has_references {
    my $self            = shift;
    my @foreign_classes = $self->relationships;
    foreach my $rel ( $self->relationships ) {
        my $rel_info = $self->relationship_info($rel);
        next unless ( $rel_info->{attrs}->{accessor} eq "multi" );
        return 1 if ( $self->$rel->count > 0 );
    }
    0;
}

# Set this as default so falls through to this if not defined in superclass
sub relationships_to_related_class { {} }

# Use this to have class specific serializations
# For instance, for some multi relationships that treat the outgoing data differently (see Hosts)
sub serialize_override { }

sub serialize_to_hash {
    my ( $self, $options ) = @_;
    $options ||= {};

    # Use this to determine how far down the serialisation has occurred. We ignore id fields
    # for lower down objects because the ref should take care of it
    # Some more refactoring possible in custom objectclasses
    unless ( $options->{level} ) {
        $options->{level} = 0;
    }
    unless ( $options->{col_info} ) {
        $options->{col_info} = $self->get_column_information($options);
    }
    my $col_info          = $options->{col_info};
    my @requested_columns = @{ $col_info->{columns} };
    my %allowed_columns   = map { ( $_ => 1 ) } @{ $self->allowed_columns };

    # Filter to only allow allowed columns
    my %columns_to_serialize =
      map { ( $_ => 1 ) } grep { $allowed_columns{$_} } @requested_columns;

    my %has_a         = %{ $col_info->{has_a} };
    my %has_many      = %{ $col_info->{has_many} };
    my %many_to_many  = %{ $col_info->{many_to_many} };
    my $this_type     = $col_info->{this_type};
    my $has_variables = $col_info->{has_variables};
    my $data          = {};

    # Allow overriding of serialization
    $self->serialize_override( $data, \%columns_to_serialize, $options );

    foreach my $simple_col ( keys %columns_to_serialize ) {
        next
          if (
               $has_a{$simple_col}
            || $has_many{$simple_col}
            || $many_to_many{$simple_col}
          );
        next if ( $options->{level} && $simple_col eq "id" );
        $data->{$simple_col} = $self->$simple_col;
    }
    foreach ( keys %has_a ) {
        next unless $columns_to_serialize{$_};
        if ( $self->$_ ) {
            $data->{$_} = { name => $self->$_->name, };

            # Only display a ref if the object has a type in Opsview
            if ( $has_a{$_} && $options->{ref_prefix} ) {
                $data->{$_}->{ref} =
                  join( "/", $options->{ref_prefix}, $has_a{$_},
                    $self->$_->id );
            }
        }
        else {
            $data->{$_} = undef;
        }
    }
    foreach my $relative ( keys %many_to_many ) {
        next unless $columns_to_serialize{$relative};
        $data->{$relative} = [];
        foreach my $rel ( $self->$relative ) {
            my $hash = { name => $rel->name };
            if ( $options->{ref_prefix} ) {
                $hash->{ref} = join( "/",
                    $options->{ref_prefix},
                    $many_to_many{$relative}, $rel->id );
            }
            push @{ $data->{$relative} }, $hash;
        }
    }
    foreach my $relative ( keys %has_many ) {
        next unless $columns_to_serialize{$relative};
        $data->{$relative} = [];
        foreach my $rel ( $self->$relative ) {
            my $hash = { name => $rel->name };
            if ( $options->{ref_prefix} ) {
                $hash->{ref} = join( "/",
                    $options->{ref_prefix},
                    $has_many{$relative}, $rel->id );
            }
            push @{ $data->{$relative} }, $hash;
        }
    }
    if ( $columns_to_serialize{variables} && $has_variables ) {
        my @vars;
        my $vars_hash = $self->variables;
        foreach my $v ( sort keys %$vars_hash ) {
            push @vars,
              {
                name  => $v,
                value => $vars_hash->{$v}
              };
        }
        $data->{variables} = \@vars;
    }

    # Check for no objects
    foreach my $k ( keys %$data ) {
        if ( my $r = ( ref( $data->{$k} ) ) !~ /^(|ARRAY|HASH)$/ ) {
            warn( "key $k with value $data->{$k} is not expected with ref $r"
            );
        }
    }
    return $data;
}

sub get_column_information {
    my ( $self, $attrs ) = @_;

    my $allcols = convert_to_arrayref( $attrs->{columns} );
    my $relinfo = $self->relationships_to_related_class;

    # Given list of columns, split out all the ones prefixed with a "-" for removal
    my %allcols    = ();
    my %removecols = ();
    foreach my $col (@$allcols) {
        if ( $col =~ s/^-// ) {
            $removecols{$col} = 1;
        }
        else {
            $allcols{$col} = 1;
        }
    }

    # If no cols specified, generate from list of allowed columns
    if ( !%allcols ) {
        %allcols = map { ( $_ => 1 ) } @{ $self->allowed_columns };
    }

    # Remove if explictly defined
    foreach my $remove ( keys %removecols ) {
        delete $allcols{$remove};
    }

    # Ta-da! List of columns left
    $allcols = [ keys %allcols ];

    my ( @cols, %has_a, %has_many, %many_to_many );
    my $has_variables = 0;
    foreach my $col (@$allcols) {
        if ( $col eq "variables" ) {
            if ( $self->can("variables") ) {
                $has_variables = 1;
                push @cols, $col;
            }
        }
        elsif ( !exists $relinfo->{$col} ) {
            push @cols, $col;
        }
        elsif ( $relinfo->{$col}->{type} eq "single" ) {
            $has_a{$col} = $relinfo->{$col}->{class}->my_type_is;
            push @cols, $col;
        }
        elsif ( $relinfo->{$col}->{type} eq "has_many" ) {
            $has_many{$col} = $relinfo->{$col}->{class}->my_type_is;
            push @cols, $col;
        }
        elsif ( $relinfo->{$col}->{type} eq "multi" ) {
            $many_to_many{$col} = $relinfo->{$col}->{class}->my_type_is;
            push @cols, $col;
        }
        elsif ( $relinfo->{$col}->{type} eq "might_have" ) {
            push @cols, $col;
        }
    }
    my $this_type = $self->my_type_is;
    my $col_info  = {
        columns       => \@cols,
        has_a         => \%has_a,
        has_many      => \%has_many,
        many_to_many  => \%many_to_many,
        this_type     => $this_type,
        has_variables => $has_variables,
    };
    return $col_info;
}

1;
