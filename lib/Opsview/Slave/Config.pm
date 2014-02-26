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

# The difference between Opsview::Config and this is that these are required for each instance
# of Nagios, master or slaves
# Keep this module lightweight
package Opsview::Slave::Config;
use lib "/usr/local/nagios/etc";
use strict;
use Carp;

our $topdir = "/usr/local/nagios";
sub root_dir {$topdir}

{

    package InstanceSettings;
    use Carp;
    do "instance.cfg" or croak( "Cannot read instance.cfg: $!" );
}

sub override_base_prefix {$InstanceSettings::override_base_prefix}
sub status_dat           {$InstanceSettings::status_dat}
sub check_result_path    {$InstanceSettings::check_result_path}
sub object_cache_file    {$InstanceSettings::object_cache_file}

1;
