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

package Opsview::NotificationMethods;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 2801 $';

__PACKAGE__->table( "notificationmethods" );

__PACKAGE__->columns( Essential => qw/id name master command priority active/,
);
__PACKAGE__->columns( Other => qw/contact_variables/ );

__PACKAGE__->initial_columns(qw/name master command/);
__PACKAGE__->constrain_column_regexp(
    name => '/^[a-zA-Z0-9-]+$/' => "invalidCharactersOnlyAlphanumericsDash" );
__PACKAGE__->constrain_column_regexp( command => '/^.+$/' => "requireCommand"
);

#__PACKAGE__->has_a( system_preference => "Opsview::Systempreference");

__PACKAGE__->columns( Stringify => qw/name/ );

__PACKAGE__->default_search_attributes( { order_by => "priority" } );

=head1 NAME

Opsview::NotificationMethods - Accessing notificationmethods table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview notification methods information

=head1 METHODS

=over 4

=item $self->sms_command

Returns the sms command. At the moment, 
this interpolates the AQL information if the notification name is AQL, but the idea is
to have custom preferences for each notification method.

=cut

sub sms_command {
    my $self    = shift;
    my $command = $self->command;
    if ( $self->name eq "AQL" ) {
        my $pref             = Opsview::Systempreference->retrieve(1);
        my $aql_username     = $pref->aql_username;
        my $aql_password     = $pref->aql_password;
        my $aql_proxy_server = $pref->aql_proxy_server;
        $command =~ s/%AQL_USERNAME%/$aql_username/g;
        $command =~ s/%AQL_PASSWORD%/$aql_password/g;
        $command =~ s/%AQL_PROXY_SERVER%/$aql_proxy_server/g;
    }
    $command = "/usr/local/nagios/libexec/notifications/" . $command;
}

=item my_type_is

Returns "notification method"

=cut

sub my_type_is {
    return "notification method";
}

=head1 AUTHOR

Capside, J L Martinez

=head1 LICENSE

GNU General Public License v2

=cut

1;
