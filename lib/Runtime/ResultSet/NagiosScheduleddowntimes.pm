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

package Runtime::ResultSet::NagiosScheduleddowntimes;

use strict;
use warnings;

use base qw/Runtime::ResultSet/;

sub delete_downtimes_by_start_time_comment {
    my ( $self, $contact_obj, $config ) = @_;
    my $author  = $contact_obj->name;
    my $start   = $config->{start_timev} || "";
    my $comment = $config->{comment} || "";

    my $downtime_args = ";" . join( ";", $start, $comment );

    Opsview::Auditlog->create(
        {
            username => $author,
            text     => "Downtime deleted with args '$downtime_args'",
        }
    );

    my @errors;
    try {
        my $cmd = Opsview::Externalcommand->new(
            command => "DEL_DOWNTIME_BY_START_TIME_COMMENT",
            args    => $downtime_args,
        );
        $cmd->submit;
    }
    catch {
        push @errors, "Failure deleting downtime: $_";
    };
    return \@errors;
}

1;
