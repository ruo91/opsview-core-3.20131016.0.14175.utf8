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

package Nagios::Test::ServiceNotification;
use base Nagios::Execute;

# TODO: Need to complete
sub new {
    my $class = shift;
    my %envs  = (
        NAGIOS_HOSTNAME         => "TestHost",
        NAGIOS_HOSTALIAS        => "Test host",
        NAGIOS_HOSTADDRESS      => "10.10.10.10",
        NAGIOS_HOSTSTATE        => "DOWN",
        NAGIOS_HOSTSTATEID      => 1,
        NAGIOS_HOSTSTATETYPE    => "SOFT",
        NAGIOS_HOSTLATENCY      => "0.777",
        NAGIOS_HOSTOUTPUT       => "Host is down (not really)",
        NAGIOS_HOSTPERFDATA     => "down=1",
        NAGIOS_HOSTCHECKCOMMAND => "check_host",
        NAGIOS_SERVICEDESC      => "Servicecheck",
        NAGIOS_SERVICESTATE     => "CRITICAL",
        NAGIOS_SERVICESTATEID   => 2,
    );
    $class->SUPER::new(@_);
}

1;
