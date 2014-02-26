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

package ClassDBIExtrasBase;
use Class::Data::Inheritable;
use base "Class::Data::Inheritable";
__PACKAGE__->mk_classdata( "validation_regexp" );

# This is WRONG! Setting hash means the data is shared across all subclasses
# Need to set a new hash for each class. See validation_regexp for a working example
__PACKAGE__->mk_classdata( foreign_keys => {} );

package ClassDBIExtras;

use strict;
use Class::DBI::Sweet;
use base qw/ClassDBIExtrasBase Class::DBI::Sweet/;
use Class::Data::Inheritable;

# The two below are WRONG! See foreign_keys
__PACKAGE__->mk_classdata( has_many_fields     => [] );
__PACKAGE__->mk_classdata( ignore_clone_fields => [] );

=head1 NAME

ClassDBIExtras - Some nice extras for Class::DBI

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Extra stuff for Class::DBI

=head1 METHODS

=over 4

=item find_or_create

Overrides Class::DBI's find_or_create. The 1st hash is passed through to Class::DBI's find_or_create. If a 2nd hash is entered, will set the data to that and 
then update the object

=cut

sub find_or_create {
    my ( $class, $primary_hash, $extra_hash ) = @_;
    my $obj = $class->SUPER::find_or_create($primary_hash);
    if ($extra_hash) {
        foreach my $key ( keys %$extra_hash ) {
            $obj->$key( $extra_hash->{$key} );
        }
        $obj->update;
    }
    return $obj;
}

sub initial_columns {
    my ( $class, @list ) = @_;
    return $class->mk_classdata( 'initial_columns', \@list );
}

=item $class->constrain_column_regexp( $column, $regexp, $error )

Sets up a constraint based on regexp, which has to be in a string format, eg q{/^\w+$/}. Will call $class->constrain_column($column, $regexp).
Also saves the regexp in $class->validation_regexp so that the regexp and column can be accessed via TT

=cut

sub constrain_column_regexp {
    my ( $class, $column, $regexp, $error ) = @_;
    my $qr;
    eval '$qr = qr' . $regexp . ';';
    $class->_croak("Invalid regexp: $regexp") if $@;
    my $h = $class->validation_regexp || {};
    $h->{$column} = $regexp;
    $h->{ $column . "_error" } = $error;
    $class->validation_regexp($h);
    $class->constrain_column( $column => $qr );
}

=item retrieve_all_arrayref

Added because of problems with TT2.15. Seems to get confused by data that is returned as class dbi iterators.
This will do a retrieve_all and always return an arrayref

=cut

sub retrieve_all_arrayref { [ shift->retrieve_all ] }

=item $self->count_hasmany($colname)

Returns a count of the number of things in $colname. Like { @a = $self->$colname; return scalar @a }, but faster

=cut

sub count_hasmany {
    my ( $self, $colname ) = @_;
    my @a = $self->$colname;
    return scalar @a;
}

sub as_xml {
    my ($self) = @_;
    my $h = $self->as_hash;
    require Opsview::XML;
    my $x = Opsview::XML->new(
        {
            data   => $h,
            object => $self
        }
    );
    $x->serialize;
    return $x->body;
}

sub from_xml {
    my ( $class, $body ) = @_;
    return {} unless defined $body;
    require Opsview::XML;
    my $x = Opsview::XML->new(
        {
            body   => $body,
            object => $class
        }
    );
    $x->deserialize;
    return $x->data;
}

=item $self->as_hash 

Returns the object in a hash form, such as:

{ 
 name => "host24",
 alias => "DNS server",
 check_command => { id => 1 },
 servicechecks => [ { id => 45 }, { id => 56 }, { id => 2 } ],
 ...,
}
 
This is useful for cloning (which becomes a case of merging hashes), or for serialising

=cut

sub as_hash {
    my ($self) = @_;
    my $h;
    foreach my $attr ( $self->columns ) {
        next if $attr =~ /^(id|uncommitted)$/;
        $_ = _flatten( $self->$attr );
        $h->{$attr} = $_;
    }
    foreach my $attr ( @{ $self->has_many_fields } ) {

        #$h->{$attr} = { Opsview::Object::Host->foreign_keys->{$attr}->moniker => _flatten([ $self->$attr ]) };
        $h->{$attr} = _flatten( [ $self->$attr ] );
    }
    return $h;
}

# Recursive function - removes the classes for hashes and arrays
use Carp;
use attributes qw(reftype);

sub _flatten {
    my ($a) = @_;
    return $a unless defined $a;
    if ( ref($a) eq '' ) {

        # Is a scalar
        return $a;
    }
    elsif ( reftype($a) eq "HASH" ) {
        return { id   => $a->{id} }   if ( exists $a->{id} );
        return { name => $a->{name} } if ( exists $a->{name} );
        croak "Primary key is not id or name?";
    }
    elsif ( reftype($a) eq "ARRAY" ) {
        my @a = map { $_ = _flatten($_) } @$a;
        return \@a;
    }
    else {
        croak "Wierd object here";
    }
}

# A lot of magic happens here
# Works great for has_a relationships
# has_many relationships are a bit more tricky
# might_have are not here at all
sub foreign_keys {
    my $class = shift;
    my $keys  = $class->SUPER::foreign_keys;
    if ( scalar %$keys == 0 ) {
        my $meta_info = $class->meta_info;
        my %foreign;
        foreach my $col ( keys %{ $meta_info->{has_a} } ) {
            $foreign{$col} = $meta_info->{has_a}->{$col}->{foreign_class};
        }
        foreach my $col ( @{ $class->has_many_fields } ) {
            my $mapping_class = $meta_info->{has_many}->{$col}->{foreign_class};
            my $mapping_column =
              $meta_info->{has_many}->{$col}->{args}->{mapping}->[0]
              ; # Now, this could be dodgy...
            if ( defined $mapping_column ) {
                $foreign{$col} =
                  $mapping_class->meta_info->{has_a}->{$mapping_column}
                  ->{foreign_class};
            }
            else {
                $foreign{$col} = $mapping_class;
            }
        }
        $class->SUPER::foreign_keys( \%foreign );
    }
}

# Override method so that before_create triggers can set default values without
# entering recursive loop
sub _flesh {
    my $this = shift;
    if ( ref($this) && $this->_undefined_primary ) {
        $this->call_trigger( "select" );
        return $this;
    }
    return $this->SUPER::_flesh(@_);
}

=item __PACKAGE__->has_datetime('column');

Define a column as being a DateTime object. Expects DB to store in UTC. Will then convert to local timezone. 
Warning: This is likely to be slow, so be careful if you need speed

=cut

sub has_datetime {
    my $class = shift;
    my ($field) = @_;
    $class->has_a(
        $field  => 'DateTime',
        inflate => sub {
            my $time = shift;
            return DateTime->from_epoch(
                epoch     => 0,
                time_zone => "local"
            ) if ( $time eq "0000-00-00 00:00:00" );
            $_ = DateTime::Format::MySQL->parse_datetime($time);
            $_->set_time_zone( "UTC" );
            $_->set_time_zone( "local" );
            $_;
        },
        deflate => sub { DateTime::Format::MySQL->format_datetime(shift) },
    );
}

# For compatability with DBIx::Class
sub has_column { shift->find_column(@_) }

package Class::DBI::Iterator;

# rewrite method calls to 'all' to redirect to 'data' method
# This is to match method call between DBIx::Class and Class::DBI
*all = \&data;

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
