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
package Opsview::Utils::NotificationTemplate;

use strict;
use warnings;

use FindBin qw($Bin);
use Template;
use Getopt::Std;
use Opsview::Config::Notifications;

# decode embedded newlines for notifications when specified
sub ov_decode_newlines {
    my $s = shift;
    $s =~ s/\\n/\n/g;
    return $s;
}

sub process {
    my ( $class, $filename, $scalar_ref, $error ) = @_;

    my @vars = grep {s/NAGIOS_(.*)/$1/} keys %ENV;
    my $vars;

    $vars->{nagios}->{ lc $_ } = $ENV{"NAGIOS_$_"} foreach @vars;

    if ( $ENV{"NAGIOS_CONTACTGROUPLIST"} ) {
        foreach ( split /,/, $ENV{"NAGIOS_CONTACTGROUPLIST"} ) {
            next if ( m/hostgroup/ || m/servicegroup/ );
            $_ =~ s/k\d+_//;
            $vars->{nagios}->{keywords} .= "$_ ";
        }
    }

    # Possible improvement in future is to only load the variables required, but is easiest to just load all of this now
    $vars->{config} = Opsview::Config::Notifications->config_variables;

    my $template = Template->new(
        {
            INCLUDE_PATH => [ $Bin, '/usr/local/nagios/libexec/notifications' ],
            FILTERS => { ov_decode_newlines => \&ov_decode_newlines, }
        }
    );

    my @extra;
    push @extra, $scalar_ref if $scalar_ref;
    my $ok = $template->process( $filename, $vars, @extra );
    if ( !$ok ) {
        $$error = $template->error;
    }
    return $ok;
}

1;
