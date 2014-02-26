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

package Opsview::ResultSet::Monitoringservers;

use strict;
use warnings;
use Opsview::Connections;
use Opsview::Config;
use Carp;

use base qw/Opsview::ResultSet/;

sub synchronise_intxn_post {
    my ( $self, $ms, $attrs, $errors ) = @_;

    # Set the related host to be this master
    if ( $ms->is_master ) {
        my $host = $ms->host;
        if ($host) {
            $host->update( { monitored_by => $ms } );
        }
        $self->result_source->schema->resultset("Hosts")
          ->search( { monitored_by => undef } )
          ->update( { monitored_by => $ms } );
    }
}

sub restrict_by_contact_role_arrayref {
    my ($self) = @_;
    my @a = $self->user->role->monitoringservers;
    \@a;
}

sub restrict_by_user {
    my ( $self, $user ) = @_;
    return $self;
}

sub search_slaves { shift->search( { "id" => { ">" => 1 } } ) }

# Returns a hash of $lookup{$host->id} = $monitoringserver
sub monitoringserverhosts_lookup {
    my ($self) = @_;
    my $lookup;
    foreach my $ms ( $self->all ) {
        if ( $ms->is_master ) {
            $lookup->{ $ms->host->id } = $ms;
        }
        else {
            map { $lookup->{ $_->host->id } = $ms } ( $ms->nodes );
        }
    }
    $lookup;
}

sub write_connections_file {
    my $self = shift;
    my $file = Opsview::Connections->connections_file;
    open F, "> $file" or croak( "Cannot write to $file" );
    my $rs =
      $self->result_source->schema->resultset( "Monitoringclusternodes" );
    if ( Opsview::Config->slave_initiated ) {
        while ( my $node = $rs->next ) {
            print F join( ":",
                $node->name, $node->is_activated,
                "127.0.0.1", $node->slave_port ),
              $/;
        }
    }
    else {
        while ( my $node = $rs->next ) {
            print F
              join( ":", $node->name, $node->is_activated, $node->ip, 22 ), $/;
        }
    }
    close F;
}

1;
