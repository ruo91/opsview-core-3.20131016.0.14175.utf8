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
package Opsview::Utils::Time;

use strict;
use warnings;
use DateTime::Format::Duration::DurationString;

# Can croak if cannot parse
sub jira_duration_to_seconds {
    my ( $class, $string ) = @_;
    if ( $string =~ /^\d+$/ ) {
        $string .= "s";
    }
    DateTime::Format::Duration::DurationString->new()->parse($string)
      ->to_seconds;
}

use Time::Interval;

sub seconds_to_jira_duration {
    my ( $class, $seconds ) = @_;
    no warnings;
    return "" unless defined $seconds && ( $seconds > 0 );
    return parseInterval(
        seconds => $seconds,
        Small   => 1
    );
}

1;
