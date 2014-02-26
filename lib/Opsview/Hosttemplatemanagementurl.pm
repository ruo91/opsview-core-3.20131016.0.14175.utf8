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

package Opsview::Hosttemplatemanagementurl;
use base 'Opsview';

use strict;

__PACKAGE__->table( "hosttemplatemanagementurls" );

__PACKAGE__->columns( Primary   => qw/id/, );
__PACKAGE__->columns( Essential => qw/hosttemplateid name url priority/, );

__PACKAGE__->has_a( hosttemplateid => "Opsview::Hosttemplate" );
__PACKAGE__->constrain_column_regexp(
    url => '/^(\w+):\/\//' => "requireProtocol" );
__PACKAGE__->constrain_column_regexp(
    name => '/^[\w]+[\w\s.-]+$/' => "invalidCharacters", );
__PACKAGE__->add_trigger( before_create => \&check_name_set );

sub check_name_set {
    my $self = shift;
    unless ( $self->{name} ) {
        $self->_croak( "Must specify a name to create a new hostgroup" );
    }
}

=head1 NAME

Opsview::HosttemplateManagementurl - Joining hosttemplates and management urls

=head1 DESCRIPTION

Handles interaction with database for Opsview hosttemplate_managementurls information

=head1 METHODS

=over 4


=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
