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

package Opsview::Applicationplugin;
use strict;
use warnings;
use Opsview;
use base qw(Opsview);

__PACKAGE__->table( "application_plugins" );

__PACKAGE__->columns( All  => qw/name menu link version created updated/, );
__PACKAGE__->columns( TEMP => qw/new_version/, );

sub after_create {
    my $self = shift;
    my $time = time;
    $self->created(time);
    $self->update;
}

__PACKAGE__->add_trigger( after_create => \&after_create );
__PACKAGE__->add_trigger( before_update => sub { shift->updated(time) } );

=head1 NAME

Opsview::Applicationplugin - List all plugins added to Opsview

=head1 DESCRIPTION

Similar to Utils::DBVersion. Will allow updating of the version information based on the name
of the plugin. The version part is a 3 digit version number

=head1 METHODS

=over 4

=item $self->is_lower("2.7.3")

Returns true if $self->version is lower than 2.7.3. Will save this new version number so can be updated later on

=cut

sub is_lower {
    my ( $self, $target ) = @_;
    my $current_version = $self->version;
    unless ( defined $current_version ) {
        $self->new_version($target);
        return 1;
    }

    my @t = split( /[\.-]/, $target );
    my @v = split( /\./,    $current_version );

    if ( ( $v[0] <=> $t[0] || $v[1] <=> $t[1] || $v[2] <=> $t[2] ) == -1 ) {
        $self->new_version($target);
        return 1;
    }
    else {
        return 0;
    }
}

=item $self->db_updated

Updates version tables with the target version as the update has completed

=cut

sub db_updated {
    my ($self) = @_;
    $self->version( $self->new_version );
    $self->update;
}

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
