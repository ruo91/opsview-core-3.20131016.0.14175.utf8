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

package Opsview::ResultSet::Servicechecks;

use strict;
use warnings;
use Carp;

use base qw/Opsview::ResultSet/;
use Opsview::Utils qw(convert_to_arrayref);

sub auto_create_foreign {
    { "keywords" => 1, };
}

sub synchronise_intxn_pre_insert {
    my ( $self, $object, $attrs, $errors ) = @_;

    # Validate service group is selected
    if ( !$attrs->{servicegroup} ) {
        push @$errors, "Service group not specified";
    }

    # active checks must have a plugin specified - we just set to the first one
    if (
        (
               !exists $attrs->{checktype}
            || !defined $attrs->{checktype}
            || $attrs->{checktype}->id == 1
        )
        && !$attrs->{plugin}
      )
    {
        push @$errors, "Plugin not specified";
    }
}

sub synchronise_intxn_many_to_many_pre {
    my ( $self, $obj, $attrs ) = @_;

    # Remove dependencies if same as self
    if ( $attrs->{dependencies} ) {
        $attrs->{dependencies} =
          [ grep { $_->id != $obj->id } @{ $attrs->{dependencies} } ];
    }
}

sub list_servicechecks_by_host {
    my ( $self, $hostids ) = @_;
    $hostids = convert_to_arrayref($hostids);
    my $by_host_specific = $self->search(
        { "hostservicechecks.hostid" => { "-in" => $hostids } },
        {
            join     => "hostservicechecks",
            distinct => 1
        }
    );
    my %scs;
    while ( my $sc = $by_host_specific->next ) {
        $scs{ $sc->name } = $sc;
    }
    my $by_hosttemplates = $self->search(
        { "hosthosttemplates.hostid" => { "-in" => $hostids } },
        {
            join => {
                "hosttemplateservicechecks" =>
                  { "hosttemplateid" => "hosthosttemplates" }
            },
            distinct => 1
        }
    );
    while ( my $sc = $by_hosttemplates->next ) {
        $scs{ $sc->name } = $sc;
    }
    my @a =
      map { $scs{$_} }
      sort { uc($a) cmp uc($b) } map { $scs{$_}->name } keys %scs;
    return @a;
}

sub add_dependency_levels {
    my ($self) = @_;

    # Make everything set to level at bottom
    $self->update( { dependency_level => 0 } );

    foreach my $sc ( $self->search ) {
        $sc->set_dependency_level(0);
    }
}

1;
