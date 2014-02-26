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

# Keep this lean - used by notifications
package Opsview::Config::Notifications;
use warnings;
use strict;

our $configfile = $ENV{OPSVIEW_SLAVE_CONFIGFILE}
  || "/usr/local/nagios/etc/notificationmethodvariables.cfg";
our $notificationmethodvariables;
our $config;

sub read_config {
    my $class = shift;
    unless ($notificationmethodvariables) {
        require "$configfile";
    }
}

sub notification_variables {
    my ( $class, $namespace ) = @_;
    $class->read_config;
    return $notificationmethodvariables->{$namespace};
}

sub config_variables {
    my $class = shift;
    $class->read_config;
    return $config;
}

1;
