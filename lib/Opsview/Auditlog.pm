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

package Opsview::Auditlog;
use base qw/Opsview/;

use strict;
use DateTime;
use DateTime::Format::MySQL;

__PACKAGE__->table( "auditlogs" );

__PACKAGE__->columns( Primary   => qw/id/ );
__PACKAGE__->columns( Essential => qw/datetime username reloadid notice text/ );

__PACKAGE__->utf8_columns( qw(text) );

__PACKAGE__->default_search_attributes( { order_by => "id DESC" } );

__PACKAGE__->has_datetime( 'datetime' );

__PACKAGE__->add_trigger(
    before_create => sub {
        my $self = shift;
        $self->{datetime} = DateTime->now( time_zone => "UTC" )
          unless ( $self->{datetime} );
    }
);

# Convenience function
sub system {
    my ( $class, $text ) = @_;
    $class->create(
        {
            username => "",
            text     => $text,
        }
    );
}

sub delete_old_auditlogs {
    my ( $class, $age ) = @_;
    return unless ( $age > 0 );
    $class->db_Main->do(
        "DELETE FROM auditlogs WHERE datetime < ( NOW() - INTERVAL $age DAY )"
    );
}

sub insert_audit_proxy_log {
    my ( $class, $entry ) = @_;
    if ( $entry =~ /^\[(\d+)\] API LOG: (\w+?);(.*)$/ ) {
        my $text = "CGI command: $3";
        $class->create(
            {
                datetime => DateTime->from_epoch(
                    epoch     => $1,
                    time_zone => "UTC"
                ),
                username => $2,
                text     => $text
            }
        );
    }
}

=item my_type_is

Returns "audit log"

=cut

sub my_type_is {
    return "audit log";
}
1;
