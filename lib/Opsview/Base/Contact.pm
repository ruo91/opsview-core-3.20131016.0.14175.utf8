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

# This package is for common contructs between Class::DBI and DBIx::Class
# versions of the model
# Common methods are added here. Aim is to remove Class::DBI over time, so
# then this file can be removed

package Opsview::Base::Contact;

use warnings;
use strict;

# Specify the required classes here. Testing needs to pull these in
# and no harm expecting it here
use Utils::SQL::Abstract;

# Don't use Runtime here, only as necessary. This is because an install
# may run populate_db.pl without the runtime db existing
# Don't use Opsview::* either, as this seems to affect the loading process for populate_db.pl

=item $self->can_change_service($runtime_service_obj)

Checks if the contact is allowed to amend this object from the runtime database
as per runtime database tables.  Returns the oject if permissions are ok, 
else undef

=cut

sub can_change_service {
    my ( $self, $runtime_service ) = @_;

    if ( $self->has_access("ACTIONALL") ) {
        return $runtime_service;
    }

    if ( $self->has_access("ACTIONSOME") ) {
        my $dbh = $runtime_service->db_Main;
        my $sql = qq{
			SELECT service_object_id
			FROM opsview_contact_services
			WHERE contactid = ?
			AND   service_object_id = ?
		};
        my $sth = $dbh->prepare($sql);
        require Runtime::Service;
        return (
            Runtime::Service->sth_to_objects(
                $sth, [ $self->id, $runtime_service->id ]
            )
        )[0];
    }

    return;
}

=item can_view_all

Returns true if this contact can view everything

=cut

sub can_view_all {
    my $self = shift;
    return 1 if ( $self->has_access("VIEWALL") );
    return 0;
}

=item $self->can_view_object_by_name( { hostname => $hostname, servicename => $servicename } )

Checks if the contact has view access for this object. Requires $hostname. Requires $servicename to check for
a specific service on $hostname. Returns true if ok, else false

=cut

sub can_view_object_by_name {
    my ( $self, $args ) = @_;
    die "Need hostname" unless $args->{hostname};
    if ( $self->can_view_all ) {
        return 1;
    }
    my $where = {};
    $where->{"opsview_contact_services.service_object_id"} =
      \"= opsview_host_services.service_object_id";
    $where->{"opsview_contact_services.contactid"} = $self->id;
    $where->{hostname} = $args->{hostname};
    $where->{servicename} = $args->{servicename} if exists $args->{servicename};
    my ( $stmt, @bind ) = Utils::SQL::Abstract->new->select(
        [ "opsview_contact_services", "opsview_host_services" ],
        ["COUNT(*)"], $where, );
    require Runtime;
    my $dbh = Runtime->db_Main;
    my $val = $dbh->selectrow_array( $stmt, {}, @bind );
    return $val;
}

=item $self->can_change_object_by_name( { hostname => $hostname, servicename => $servicename } )

Checks if the contact has change access for this object. Requires $hostname. Requires $servicename to check for
a specific service on $hostname. Returns true if ok, else false

=cut

sub can_change_object_by_name {
    my ( $self, $args ) = @_;

    die "Need hostname" unless $args->{hostname};

    if ( $self->has_access("ACTIONALL") ) {
        return 1;
    }

    if ( $self->has_access("ACTIONSOME") ) {
        my $where = {};
        $where->{"opsview_contact_services.service_object_id"} =
          \"= opsview_host_services.service_object_id";
        $where->{"opsview_contact_services.contactid"} = $self->id;
        $where->{hostname}                             = $args->{hostname};
        $where->{servicename}                          = $args->{servicename}
          if exists $args->{servicename};
        my ( $stmt, @bind ) = Utils::SQL::Abstract->new->select(
            [ "opsview_contact_services", "opsview_host_services" ],
            ["COUNT(*)"], $where, );
        require Runtime;
        my $dbh = Runtime->db_Main;
        my $val = $dbh->selectrow_array( $stmt, {}, @bind );
        return $val;
    }

    return;
}

=item $self->hostgroups

Overrides the hostgroups to return all hostgroups if all_hostgroup attribute is set

=cut

sub hostgroups {
    my $self = shift;
    require Opsview::Hostgroup;
    if ( $self->all_hostgroups ) {
        my @objs = Opsview::Hostgroup->retrieve_all;
        return @objs;
    }
    else {
        my @objs = $self->_hostgroups;
        return @objs;
    }
}

=item $self->servicegroups

Overrides servicegroups to return all servicegroups if all_servicegroup attribute is set

=cut

sub servicegroups {
    my $self = shift;
    require Opsview::Servicegroup;
    if ( $self->all_servicegroups ) {
        my @objs = Opsview::Servicegroup->retrieve_all;
        return @objs;
    }
    else {
        my @objs = $self->_servicegroups;
        return @objs;
    }
}

=item contactgroups

Returns the name of the contact groups this contact is authorised to view

=cut

# Not quite sure why ->all is required, but doesn't work with contact's role hostgroups otherwise
sub contactgroups {
    my $self = shift;
    my @cgs  = ();
    my @sgs  = $self->servicegroups->all;
    foreach my $hg ( $self->hostgroups->all ) {
        foreach my $sg (@sgs) {
            push @cgs, "hostgroup" . $hg->id . "_servicegroup" . $sg->id;
        }
    }
    foreach my $k ( $self->keywords->all ) {
        push @cgs, 'k' . $k->id . '_' . $k->name;
    }
    return @cgs;
}

sub is_admin {
    my $self = shift;
    if ( $self->has_access("ADMINACCESS") ) {
        return 1;
    }
    return 0;
}

1;
