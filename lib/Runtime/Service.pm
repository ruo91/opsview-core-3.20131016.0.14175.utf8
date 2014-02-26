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

package Runtime::Service;
use base 'Runtime';
use base ( qw(Runtime::Action Utils::ContextSave) );
use Opsview::Externalcommand;
use Opsview::Auditlog;

use strict;

__PACKAGE__->table( "opsview_host_services" );

__PACKAGE__->columns( Primary => qw/service_object_id/ );
__PACKAGE__->columns(
    Essential => qw/servicename host_object_id hostname servicecheck_id/ );
*id   = \&service_object_id;
*name = \&servicename;

__PACKAGE__->might_have( servicestatus => "Runtime::Servicestatus" =>
      qw(current_state output last_check scheduled_downtime_depth problem_has_been_acknowledged)
);
__PACKAGE__->has_a( host_object_id => "Runtime::Host" );

=head1 NAME

Runtime::Service - Accessing opsview_host_services table

=head1 DESCRIPTION

Handles interaction with database for Runtime's shost/service information

This links with runtime.hosts table

=head1 METHODS

=item $self->downtime( { start => $start, end => $end, comment => $comment } )

Will set up (if hash passed) or cancel (if no hash) scheduled downtime for
the service.  Both $start end $end are times in epoch format and should
have been previously validated.

Returns true if successful, otherwise sets $@ to error

=cut

sub downtime {
    my ( $self, $config ) = @_;
    my $author = $self->username;
    if ( ref($config) eq "HASH" ) {

        #enable
        my $start = $config->{start};
        my $end   = $config->{end};

        # TODO: Should work out i18n, but requires context for this
        Opsview::Auditlog->create(
            {
                username => $author,
                text     => "Downtime scheduled for service "
                  . $self->name . " on "
                  . $self->hostname
                  . ": starting "
                  . scalar localtime($start)
                  . ", ending "
                  . scalar localtime($end) . ": "
                  . $config->{comment},
            }
        );

        eval {
            my $comment =
                "Service '"
              . $self->name
              . "' on host '"
              . $self->hostname . "': "
              . $config->{comment};
            my $cmd = Opsview::Externalcommand->new(
                command => "SCHEDULE_SVC_DOWNTIME",
                args    => $self->hostname . ';'
                  . $self->name
                  . ";$start;$end;1;0;;$author;$comment",
            );
            $cmd->submit;
        };
    }
    else {

        # disable
        Opsview::Auditlog->create(
            {
                username => $author,
                text     => "Downtime deleted for service "
                  . $self->hostname
                  . " host "
                  . $self->name,
            }
        );

        eval {
            my $cmd = Opsview::Externalcommand->new(
                command => "DEL_SVC_DOWNTIME",
                args    => $self->hostname . ';' . $self->name,
            );
            $cmd->submit;
        };
    }
    return 1 unless ($@);
    return undef;
}

=item list_all_host_downtime_by_comment

Returns a list of all downtime for the host, grouped by comment and
entry_time

=cut

sub list_all_service_downtime_by_comment {
    my ($self) = @_;

    # Need to check for host or services
    my $sql = "
        SELECT nsd.scheduleddowntime_id
        FROM opsview_host_services ohs
        LEFT JOIN nagios_scheduleddowntime nsd ON (nsd.object_id = ohs.service_object_id OR nsd.object_id = ohs.host_object_id)
        WHERE ohs.service_object_id = ?  AND nsd.scheduleddowntime_id IS NOT NULL
        GROUP BY
            nsd.comment_data,nsd.entry_time
        ORDER BY
            nsd.comment_data,nsd.scheduled_start_time
    ";

    my $sth = $self->db_Main->prepare_cached($sql);
    return Runtime::Downtime->sth_to_objects( $sth, [ $self->id ] );
}

=item $obj->can_set_downtime_by($contact_obj)

Check whether or not the given object can set downtime according to the contact

Returns true or false

=cut

# Could do with switching to Runtime::Schema::OpsviewHostServices
sub can_set_downtime_by {
    my ( $self, $contact_obj ) = @_;

    if ( $contact_obj->has_access("DOWNTIMEALL") ) {
        return $self;
    }

    if ( $contact_obj->has_access("DOWNTIMESOME") ) {
        my $dbh = $self->db_Main;
        my $sql = qq{
            SELECT service_object_id
            FROM opsview_contact_services
            WHERE contactid = ?
            AND   service_object_id = ?
        };
        my $sth = $dbh->prepare($sql);
        return Runtime::Service->sth_to_objects( $sth,
            [ $contact_obj->id, $self->id ] )->first;
    }

    return;
}

=item $obj->can_be_changed_by($contact_obj)

Check whether or not the given object has permisions on the object

Returns the object if true, undef if false

=cut

sub can_be_changed_by {
    my ( $self, $contact_obj, $accessprefix ) = @_;

    $accessprefix ||= "ACTION";

    my %access = (
        all  => "${accessprefix}ALL",
        some => "${accessprefix}SOME",
    );

    return $self if $contact_obj->has_access( $access{all} );

    if ( $contact_obj->has_access( $access{some} ) ) {
        my $dbh = $self->db_Main;
        my $sql = qq{
            SELECT service_object_id
            FROM opsview_contact_services
            WHERE contactid = ?
            AND   service_object_id = ?
        };
        my $sth = $dbh->prepare($sql);
        return Runtime::Service->sth_to_objects( $sth,
            [ $contact_obj->id, $self->id ] )->first;
    }

    return;
}

=item my_type_is

Returns "service"

=cut

sub my_type_is {
    return "service";
}

sub is_handled {
    my $self = shift;
    return (
             $self->current_state == 0
          or $self->problem_has_been_acknowledged == 1
          or $self->scheduled_downtime_depth > 0
          or $self->host_object_id->current_state != 0
    );
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
