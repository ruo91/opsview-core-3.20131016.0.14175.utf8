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

package Opsview::Timeperiod;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 2302 $';

__PACKAGE__->table( "timeperiods" );

__PACKAGE__->columns( Primary => qw/id /, );

__PACKAGE__->columns( Essential => qw/name alias uncommitted/, );

__PACKAGE__->columns(
    Other => qw/sunday monday tuesday wednesday thursday friday saturday/, );

__PACKAGE__->columns( Stringify => qw/name/ );

__PACKAGE__->has_many(
    hosts => "Opsview::Host",
    "notification_period", { cascade => 'Fail' }
);
__PACKAGE__->has_many(
    servicechecks => "Opsview::Servicecheck",
    "notification_period", { cascade => "Fail" }
);
__PACKAGE__->has_many(
    servicechecktimedoverridehostexceptions =>
      "Opsview::Servicechecktimedoverridehostexception",
    "timeperiod", { cascade => "Fail" }
);
__PACKAGE__->has_many(
    servicechecktimedoverridehosttemplateexceptions =>
      "Opsview::Servicechecktimedoverridehosttemplateexception",
    "timeperiod", { cascade => "Fail" }
);
__PACKAGE__->has_many(
    servicechecks_timeperiod => "Opsview::Servicecheck",
    "check_period", { cascade => 'Fail' }
);

__PACKAGE__->initial_columns(qw/ name /);

=head1 NAME

Opsview::Timeperiod - Accessing timeperiods table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview time period information

=head1 METHODS

=over 4

=item my_type_is

Returns "time period"

=cut

sub my_type_is {
    return "time period";
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
