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

package Opsview::Common;
require Exporter;

use strict;
use warnings;

use Opsview::Utils::Time;
use DateTime;
use DateTime::Format::Strptime;
use DateTime::Format::Natural;

our @ISA       = qw(Exporter);
our @EXPORT    = qw( parse_downtime_strings );
our @EXPORT_OK = qw ( );
our $VERSION   = sprintf( "%d", q$Revision: 0.01 $ =~ /\d+/ );

=item ($,$) = parse_string( $string )

Takes two strings and attempts to convert them to DateTime objects.  Performs
basic checks such as can be converted, $end is after $start, and $start 
isn't too far in the past.  

Strings can be standard times (i.e. "yyyy/mm/dd hh:mm:ss") or natural language
(i.e. "now" or "now + 1 hour").

Return two date time objects set to the 'local' time zone, else returns 
undef with error in $@

=cut

sub parse_string {
    my $string = shift;
    my ( $parser, $stamp );

    # yyyy-mm-dd hh:mm:ss
    $parser = new DateTime::Format::Strptime(
        pattern   => "%F %T",
        time_zone => "local",
    );
    $stamp = $parser->parse_datetime($string);

    return $stamp if $stamp;

    # yyyy-mm-dd hh:mm
    $parser = new DateTime::Format::Strptime(
        pattern   => "%F %H:%M",
        time_zone => "local",
    );
    $stamp = $parser->parse_datetime($string);

    return $stamp if $stamp;

    # epoc
    if ( $string =~ m/^\d{10,}$/ ) {
        $stamp = DateTime->from_epoch(
            epoch     => $string,
            time_zone => "local"
        );
        return $stamp if $stamp;
    }

    # 'natural language'
    $parser = DateTime::Format::Natural->new(
        format        => "yy-mm-dd",
        prefer_future => 1,
        time_zone     => "local",
    );
    eval { $stamp = $parser->parse_datetime($string); };
    $@ = "Unable to parse date string" if ($@);

    if ( !$stamp ) {
        return undef;
    }

    return $stamp;
}

sub parse_datetime_string {
    my ( $class, $string ) = @_;
    return parse_string($string);
}

=item ($,$) = parse_downtime_strings( $start, $end )

Takes two strings and attempts to convert them to DateTime objects.  Performs
basic checks such as can be converted, $end is after $start, and $start 
isn't too far in the past.

Strings can be standard times (i.e. "yyyy/mm/dd hh:mm:ss") or natural language
(i.e. "now" or "now + 1 hour").

Return two date time objects, else returns undef with error in $@

=cut

sub parse_downtime_strings {
    my $start = shift;
    my $end   = shift;
    $@ = "";

    my ( $start_dt, $end_dt );

    # start time checks
    if ( !$start ) {
        $@ = "Start time is not defined";
        return undef;
    }
    $start_dt = parse_string($start);
    if ( !$start_dt ) {
        return undef;
    }

    if (
        $start_dt->subtract_datetime(
            DateTime->now( time_zone => "local" )->subtract( hours => 1 )
        )->is_negative
      )
    {
        $@ = "Start time is too far behind in time";
        return undef;
    }

    # end time checks
    if ( !$end ) {
        $@ = "End time is not defined";
        return undef;
    }

    # If "+" at beginning, assume is a jira style duration
    if ( $end =~ s/^\s*\+\s*// ) {
        my $seconds = undef;
        eval { $seconds = Opsview::Utils::Time->jira_duration_to_seconds($end) };
        if ($seconds) {
            $end_dt = $start_dt->clone->add( seconds => $seconds );
        }
        else {
            $@ = "Jira style duration invalid";
        }
    }
    else {
        $end_dt = parse_string($end);
    }
    if ( !$end_dt ) {
        return undef;
    }

    # start and end compared
    if ( $start_dt->epoch == $end_dt->epoch ) {
        $@ = "End time is the same as the start time";
        return undef;
    }

    if ( $start_dt->epoch > $end_dt->epoch ) {
        $@ = "End time is before start time";
        return undef;
    }

    if ( $end_dt->subtract_datetime($start_dt)->subtract( seconds => 60 )
        ->is_negative )
    {
        $@ = "Cannot specify downtime of less than 1 minute";
        return undef;
    }

    return ( $start_dt, $end_dt );
}

sub clean_comment {
    my ( $self, $comment ) = @_;
    $comment = "" unless defined $comment;
    $comment =~ s/<//g;
    $comment =~ s/>//g;
    $comment =~ s/;//g;
    $comment =~ s/\n//g;
    return $comment;
}

1;
