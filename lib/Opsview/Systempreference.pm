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

package Opsview::Systempreference;
use base 'Opsview';

use strict;

__PACKAGE__->table( "systempreferences" );

__PACKAGE__->columns( Primary   => qw/id/, );
__PACKAGE__->columns( Essential => qw/refresh_rate/, );
__PACKAGE__->columns(
    Others => qw/default_statusmap_layout
      default_statuswrl_layout log_notifications
      log_service_retries log_host_retries log_event_handlers
      log_initial_states log_external_commands log_passive_checks
      daemon_dumps_core audit_log_retention
      host_info_url hostgroup_info_url soft_state_dependencies
      opsview_server_name
      rancid_email_notification

      viewport_summary_style send_anon_data uuid updates_includemajor
      netdisco_url date_format set_downtime_on_host_delete
      /,
);

=head1 NAME

Opsview::Systempreference - preferences for Opsview

=head1 SYNOPSIS

A traditional object table, but only ever one row

=head1 METHODS

=over 4

=cut

sub _pref {
    my $self       = shift;
    my $var        = shift;
    my $newval     = shift;
    my $accessor   = "_${var}_accessor";
    my $preference = $self->retrieve(1);
    if ( defined($newval) ) {
        $preference->$accessor($newval);
        $preference->update;
    }
    return $preference->$accessor();
}

=item Opsview::Systempreference->default_statusmap_layout

=item Opsview::Systempreference->default_statuswrl_layout

=item Opsview::Systempreference->refresh_rate

=item Opsview::Systempreference->log_notifications

=item Opsview::Systempreference->log_service_retries

=item Opsview::Systempreference->log_host_retries

=item Opsview::Systempreference->log_event_handlers

=item Opsview::Systempreference->log_initial_states

=item Opsview::Systempreference->log_external_commands

=item Opsview::Systempreference->log_passive_checks

=item Opsview::Systempreference->daemon_dumps_core

=item Opsview::Systempreference->host_info_url

=item Opsview::Systempreference->hostgroup_info_url

=item Opsview::Systempreference->soft_state_dependencies

=item Opsview::Systempreference->rancid_email_notification

=item Opsview::Systempreference->send_anon_data

=item Opsview::Systempreference->uuid

=item Opsview::Systempreference->updates_includemajor

=item Opsview::Systempreference->date_format

=item Opsview::Systempreference->set_downtime_on_host_delete

Returns the current setting for the configuration requested

=cut

sub default_statusmap_layout {
    return _pref( shift, "default_statusmap_layout", shift );
}

sub default_statuswrl_layout {
    return _pref( shift, "default_statuswrl_layout", shift );
}
sub refresh_rate        { return _pref( shift, "refresh_rate",        shift ); }
sub log_notifications   { return _pref( shift, "log_notifications",   shift ); }
sub log_service_retries { return _pref( shift, "log_service_retries", shift ); }
sub log_host_retries    { return _pref( shift, "log_host_retries",    shift ); }
sub log_event_handlers  { return _pref( shift, "log_event_handlers",  shift ); }
sub log_initial_states  { return _pref( shift, "log_initial_states",  shift ); }

sub log_external_commands {
    return _pref( shift, "log_external_commands", shift );
}
sub log_passive_checks  { return _pref( shift, "log_passive_checks",  shift ); }
sub daemon_dumps_core   { return _pref( shift, "daemon_dumps_core",   shift ); }
sub audit_log_retention { return _pref( shift, "audit_log_retention", shift ); }
sub host_info_url       { return _pref( shift, "host_info_url",       shift ); }
sub hostgroup_info_url  { return _pref( shift, "hostgroup_info_url",  shift ); }
sub opsview_server_name { return _pref( shift, "opsview_server_name", shift ); }

sub soft_state_dependencies {
    return _pref( shift, "soft_state_dependencies", shift );
}

sub rancid_email_notification {
    return _pref( shift, "rancid_email_notification", shift );
}

sub viewport_summary_style {
    return _pref( shift, "viewport_summary_style", shift );
}
sub send_anon_data { return _pref( shift, "send_anon_data", shift ) }
sub uuid           { return _pref( shift, "uuid",           shift ) }

sub updates_includemajor {
    return _pref( shift, "updates_includemajor", shift );
}
sub date_format { return _pref( shift, "date_format", shift ) }

sub set_downtime_on_host_delete {
    return _pref( shift, "set_downtime_on_host_delete", shift );
}

sub identity_string {""}
__PACKAGE__->mk_classdata( class_title => "system preference" );

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
