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

package Opsview::ResultSet::Timeperiods;

use strict;
use warnings;
use Carp;

use base qw/Opsview::ResultSet/;
use Opsview::Utils qw(convert_to_arrayref);

sub synchronise_ignores {
    {
        "host_check_periods"                => 1,
        "host_notification_periods"         => 1,
        "servicecheck_check_periods"        => 1,
        "servicecheck_notification_periods" => 1,
        "host_timed_exceptions"             => 1,
        "hosttemplate_timed_exceptions"     => 1,
    };
}

# This probably should be earlier, but okay to validate here
sub synchronise_intxn_post {
    my ( $self, $object, $attrs, $errors ) = @_;
    if ( $object->in_storage && $object->id == 1 ) {
        push @$errors, "Cannot change this timeperiod";
    }
}

1;
