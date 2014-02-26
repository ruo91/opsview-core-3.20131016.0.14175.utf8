#!/bin/sh
# Source in opsview environment variables
#
# Expects to be run with "eval `path/to/opsview.sh`" in ksh/sh
# Reads opsview.defaults and overlays with opsview.conf
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

bindir=`dirname $0`
etcdir=${bindir}/../etc
libdir=${bindir}/../lib

# Check here because slaves do not have opsview.conf
if [ ! -f $etcdir/opsview.defaults ] ; then
    # return information for use on slaves
    perl -e '
        use lib "'$etcdir'";
        do "instance.cfg";
        print <<"EOF"
ARCHIVE_RETENTION_DAYS="$archive_retention_days"
NMIS_MAXTHREADS="$nmis_maxthreads"
CHECK_RESULT_PATH="$check_result_path"
EOF
'
    exit $?
fi

# We need to keep USE_LIGHTTPD as older code uses this to check this in the
# init scripts. This affects upgrades
perl -e '
	use lib "'$libdir'";
	use Opsview::Config;
	use Opsview::Utils;
	print qq{ROOT_DIR="}.Opsview::Config->root_dir.qq{"}.$/;
	my $overrides=Opsview::Utils->make_shell_friendly($Settings::overrides);
	$overrides =~ s/^\043.*$//xmg; # remove comments
	$overrides =~ s/^\s*$//xmg;    # remove blank lines
	print <<"EOF";
DB="$Settings::db"
DBUSER="$Settings::dbuser"
DBPASSWD="$Settings::dbpasswd"
DBHOST="localhost"
BACKUP_DIR="$Settings::backup_dir"
BACKUP_RETENTION_DAYS="$Settings::backup_retention_days"
DAILY_BACKUP="$Settings::daily_backup"
ARCHIVE_RETENTION_DAYS="$Settings::archive_retention_days"
RUNTIME_DB="$Settings::runtime_db"
RUNTIME_DBUSER="$Settings::runtime_dbuser"
RUNTIME_DBPASSWD="$Settings::runtime_dbpasswd"
RUNTIME_DBHOST="localhost"
BIND_ADDRESS="$Settings::bind_address"
USE_LIGHTTPD=0
USE_HTTPS="$Settings::use_https"
NMIS_MAXTHREADS="$Settings::nmis_maxthreads"
STATUS_DAT="$Settings::status_dat"
CHECK_RESULT_PATH="$Settings::check_result_path"
OVERRIDES=$overrides
OBJECT_CACHE_FILE="$Settings::object_cache_file"
EOF
'
