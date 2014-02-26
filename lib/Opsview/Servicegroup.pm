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

package Opsview::Servicegroup;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 1929 $';

__PACKAGE__->table( "servicegroups" );

__PACKAGE__->columns( Primary   => qw/id/ );
__PACKAGE__->columns( Essential => qw/name/ );
__PACKAGE__->columns( Others    => qw/uncommitted/ );

__PACKAGE__->columns( Stringify => qw/name/ )
  ; # Causes problems with deletes - keep an eye on it

__PACKAGE__->has_many(
    servicechecks => "Opsview::Servicecheck",
    "servicegroup", { cascade => 'Fail' }
);
__PACKAGE__->has_many(
    keywords => [ "Opsview::KeywordServicegroup" => "keywordid" ],
    "servicegroupid"
);

__PACKAGE__->default_search_attributes( { order_by => "name" } );

__PACKAGE__->constrain_column_regexp(
    name => q{/^[\w .\/\+-]+$/} => "invalidCharacters", )
  ; # Must compose of alphanumerics and not empty

__PACKAGE__->initial_columns(); # See Hostgroup.pm

=head1 NAME

Opsview::Servicegroup - Accessing servicegroup table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview servicegroup information

=head1 METHODS

=over 4

=item typeid

Returns servicegroupX where X is the id of the object

=cut

sub typeid {
    my $self = shift;
    return "servicegroup" . $self->id;
}

sub all_servicechecks {
    my $self = shift;
    return ( $self->servicechecks );
}

=item my_type_is

Returns "service group"

=cut

sub my_type_is {
    return "service group";
}
sub my_web_type {"servicegroup"}

sub servicechecks_by_object {
    my ( $self, $object ) = @_;
    my $dbh = $self->db_Main;
    my (
        $joined_object,           $joined_exceptions,
        $joined_timed_exceptions, $joined_event_handlers
    );
    my ( $column_name, $column_nameid );
    my $id;
    my $has_event_handler = 1;
    my $extra_col         = "";
    my $objecttype        = ref $object;

    if ( !$object || $objecttype =~ /Hosts?$/ ) {
        $joined_object           = "hostservicechecks";
        $joined_exceptions       = "servicecheckhostexceptions";
        $joined_timed_exceptions = "servicechecktimedoverridehostexceptions";
        $joined_event_handlers   = "hostserviceeventhandlers";
        $column_name             = "host";
        $column_nameid           = "hostid";
        $id                      = $object ? $object->id : 0;
        $extra_col =
          "joined_object.remove_servicecheck as remove_servicecheck,";
    }
    elsif ( $objecttype =~ /Hosttemplates?$/ ) {
        $joined_object     = "hosttemplateservicechecks";
        $joined_exceptions = "servicecheckhosttemplateexceptions";
        $joined_timed_exceptions =
          "servicechecktimedoverridehosttemplateexceptions";

        # This is wrong, but we leave it in so the SQL work. The view will ignore this data
        $joined_event_handlers = "hostserviceeventhandlers";
        $column_name           = "hosttemplate";
        $column_nameid         = "hosttemplateid";
        $id                    = $object->id;
        $has_event_handler     = 0;
    }
    else {
        die "Invalid object";
    }
    my $sql = qq{
SELECT 
 servicechecks.id as id,
 servicechecks.name as name,
 servicechecks.description as description,
 servicechecks.checktype as checktype,
 servicechecks.args as args,
 servicechecks.plugin as plugin,
 $extra_col
 (joined_object.$column_nameid > 0) as checked,
 (joined_exceptions.$column_name > 0) as exception_checked,
 (joined_timed_exceptions.$column_name > 0) as timedoverride_checked,
};
    $sql .= "joined_event_handlers.event_handler as event_handler,"
      if $has_event_handler;
    $sql .= qq{
 joined_exceptions.args as exception_args,
 joined_timed_exceptions.args as timedoverride_args,
 joined_timed_exceptions.timeperiod as timedoverride_timeperiod
FROM servicechecks 
LEFT JOIN $joined_object joined_object 
ON (joined_object.$column_nameid = ? and joined_object.servicecheckid = servicechecks.id ) 
LEFT JOIN $joined_exceptions joined_exceptions
ON (joined_exceptions.$column_name = joined_object.$column_nameid AND servicechecks.id = joined_exceptions.servicecheck)
LEFT JOIN $joined_timed_exceptions joined_timed_exceptions
ON (joined_timed_exceptions.$column_name = joined_object.$column_nameid AND servicechecks.id = joined_timed_exceptions.servicecheck)
};
    $sql .= qq{
LEFT JOIN $joined_event_handlers joined_event_handlers
ON (joined_event_handlers.$column_nameid = joined_object.$column_nameid AND servicechecks.id = joined_event_handlers.servicecheckid)
} if $has_event_handler;
    $sql .= qq{
WHERE servicechecks.servicegroup = ?
ORDER BY servicechecks.name
};
    my $sth = $dbh->prepare_cached($sql);
    $sth->execute( $id, $self->id );
    my @results;

    while ( my $hash = $sth->fetchrow_hashref ) {
        $hash->{object} =
          Opsview::Servicecheck->construct( { id => $hash->{id} } );
        push @results, $hash;
    }
    return {
        name          => $self->name,
        object        => $self,
        servicechecks => \@results
    };
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
