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

package Opsview::Hosttemplate;
use base qw/Opsview/;
use Carp;

use strict;
our $VERSION = '$Revision: 2323 $';

__PACKAGE__->table( "hosttemplates" );

__PACKAGE__->columns( Primary   => qw/id/ );
__PACKAGE__->columns( Essential => qw/name description uncommitted/ );

__PACKAGE__->has_many(
    hosts => [ "Opsview::HostHosttemplate" => "hostid" ],
    "hosttemplateid"
);
__PACKAGE__->has_many(
    servicechecks =>
      [ "Opsview::HosttemplateServicecheck" => "servicecheckid" ],
    "hosttemplateid"
);
__PACKAGE__->has_many(
    servicecheckexceptions => ["Opsview::Servicecheckhosttemplateexception"] );
__PACKAGE__->has_many(
    keywords => [ "Opsview::KeywordHosttemplate" => "keywordid" ],
    "hosttemplateid"
);
__PACKAGE__->has_many( servicechecktimedoverrideexceptions =>
      ["Opsview::Servicechecktimedoverridehosttemplateexception"] );
__PACKAGE__->has_many(
    managementurls => ["Opsview::Hosttemplatemanagementurl"],
    { order_by => "priority" }
);

__PACKAGE__->initial_columns(qw/name/);

__PACKAGE__->default_search_attributes( { order_by => "name" } );

=head1 NAME

Opsview::Hosttemplate - Accessing hosttemplates table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview hosttemplates information

=head1 METHODS

=over 4

=item create

Creates a hosttemplate based on the hash passed in. $attrs is based on DBIx::Class's attributes, not ClassDBIExtras

  { 
    name => "Base Unix", 
    description => "Basic unix functionality",
    managementurls => [ 
      { name => "SSH", url => 'ssh://$HOSTADDRESS$' }, 
      { name => "Telnet", url => 'telnet://$HOSTADDRESS$' } 
    ],
  }

=cut

sub create {
    my ( $class, $hash_in, $attrs ) = @_;
    my $hash = {%$hash_in}; # Copy
                            # Start transaction
    local $class->db_Main->{AutoCommit}; # Turn off autocommit for block

    my $object;
    eval {

        # Create initial object
        my $initial = {};
        map { $initial->{$_} = delete $hash->{$_} }
          ( @{ $class->initial_columns } );
        $object = $class->SUPER::insert($initial);
        $object->_update($hash);
        $object->SUPER::update;

        # End transaction
    };

    if ($@) {
        my $commit_error = $@;
        eval { $class->dbi_rollback };
        croak($commit_error);
        return undef;
    }
    return $object;
}

sub _update {
    my ( $self, $hash ) = @_;
    if ( my $attr = delete $hash->{managementurls} ) {
        Opsview::Hosttemplatemanagementurl->search(
            hosttemplateid => $self->id )->delete_all;
        my $c = 1;
        foreach my $a (@$attr) {
            my $h = {};
            map { $h->{$_} = delete $a->{$_} if exists $a->{$_} }
              (qw/name url/);
            $h->{priority} = $c;
            $self->add_to_managementurls(
                {
                    hosttemplateid => $self->id,
                    %$h,
                }
            );
            $c++;
        }
    }
    foreach my $p ( keys %$hash ) {
        $self->$p( $hash->{$p} );
    }
}

sub update {
    my ( $self, $hash_in ) = @_;
    $hash_in ||= {};
    my $hash = {%$hash_in};

    # Start transaction
    $self->_update($hash);
    $self->SUPER::update;

    # End transaction
}

=item set_managementurls_to

Deletes the foreign key table and adds only the specified list of managementurls

=cut

sub set_managementurls_to {
    my $self = shift;
    Opsview::HosttemplateServicecheck->search( hosttemplateid => $self->id )
      ->delete_all;
    foreach $_ (@_) {
        $self->add_to_servicechecks(
            {
                hosttemplateid => $self->id,
                servicecheckid => $_
            }
        );
    }
}

=item set_servicechecks_to

Deletes the foreign key table and adds only the specified list of servicechecks

=cut

sub set_servicechecks_to {
    my $self = shift;
    Opsview::HosttemplateServicecheck->search( hosttemplateid => $self->id )
      ->delete_all;
    foreach $_ (@_) {
        $self->add_to_servicechecks(
            {
                hosttemplateid => $self->id,
                servicecheckid => $_
            }
        );
    }
}

=item $self->ordered_hosts

Returns a list of hosts for this hosttemplate

=cut

sub ordered_hosts {
    my $self = shift;
    Opsview::Host->by_hosttemplate($self);
}

=item my_type_is

Returns "host template"

=cut

sub my_type_is {
    return "host template";
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
