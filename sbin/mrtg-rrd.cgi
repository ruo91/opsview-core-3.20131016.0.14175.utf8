#!/usr/bin/perl -w
#
# mrtg-rrd.cgi: The script for generating graphs for MRTG statistics.
#
# Loosely modelled after the Rainer.Bawidamann@informatik.uni-ulm.de's
# 14all.cgi
#
# Amended by Opsview Limited
#
#   Copyright (C) 2001 Jan "Yenya" Kasprzak <kas@fi.muni.cz>
#   Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

use strict;

use POSIX qw(strftime);
use Time::Local;

# The %.1f should work on 5.005+. There may be other problems, though.
# I've tested this on 5.8.0 only, so mind the gap!
require 5.005;

# Location of RRDs.pm, if it is not in @INC
# use lib '/usr/lib/perl5/5.00503/i386-linux';
BEGIN {
    if ( $^O =~ m/solaris/ ) {
        my $dir = glob( '/usr/local/rrdtool-*/lib/perl' );
        unshift( @INC, $dir );
    }
}
use RRDs;

use vars qw(@config_files @all_config_files %targets $config_time
  %directories $version $imagetype);

# EDIT THIS to reflect all your MRTG config files
BEGIN { @config_files = qw(/usr/local/nagios/etc/mrtg.cfg); }

# Opsview patches
use lib "/usr/local/nagios/perl/lib", "/usr/local/nagios/lib";
use Opsview::Slave::Config;
my $opsview_base = Opsview::Slave::Config->override_base_prefix;

$version = '0.7';

# This depends on what image format your libgd (and rrdtool) uses
$imagetype = 'png'; # or make this 'gif';

# strftime(3) compatibility test
my $percent_h = '%-H';
$percent_h = '%H' if ( strftime( '%-H', gmtime(0) ) !~ /^\d+$/ );

sub mrtg_base_url {
    my $q = shift;

    my $url = $q->url( -base => 1 ) . $opsview_base . $q->url( -absolute => 1 );
    $url .= '/' unless $url =~ m,/$,;

    return $url;
}

sub handler ($) {
    my ($q) = @_;

    try_read_config( $q->url() );

    my $path = $q->path_info();
    $path =~ s/^\///;
    $path =~ s/\/$//;
    if ( defined $directories{$path} ) {
        if ( my $host = $q->param('host') ) {
            print_host( $q, $path, $host );
        }
        elsif ( $q->path_info() =~ /\/$/ ) {
            print_dir($path);
        }
        else {
            print "Location: ", $q->url( -path_info => 1 ), "/\n\n";
        }
        return;
    }

    my ( $dir, $stat, $ext ) =
      ( $q->path_info()
          =~ /^(.*)\/([^\/]+)(\.html|-(day|week|month|year|custom)\.$imagetype)\/?$/
      );

    print_error("No MRTG data available")
      unless $stat && defined $targets{$stat};

    $dir =~ s/^\///;

    print_error("Incorrect directory")
      unless defined $targets{$stat}{directory}
      || $targets{$stat}{directory} eq $dir;

    my $tgt = $targets{$stat};

    common_args( $stat, $tgt, $q );

    # We may be running under mod_perl or something. Do not destroy
    # the original settings of timezone.
    my $oldtz;
    if ( defined $tgt->{timezone} ) {
        $oldtz = $ENV{TZ};
        $ENV{TZ} = $tgt->{timezone};
    }

    if ( $ext eq '.html' ) {
        do_html($tgt);
    }
    elsif ( $ext eq '-day.' . $imagetype ) {
        do_image( $tgt, 'day' );
    }
    elsif ( $ext eq '-week.' . $imagetype ) {
        do_image( $tgt, 'week' );
    }
    elsif ( $ext eq '-month.' . $imagetype ) {
        do_image( $tgt, 'month' );
    }
    elsif ( $ext eq '-year.' . $imagetype ) {
        do_image( $tgt, 'year' );
    }
    elsif ( $ext eq '-custom.' . $imagetype ) {
        do_custom_image( $tgt, $q );
    }
    else {
        print_error( "Unknown extension" );
    }
    $ENV{TZ} = $oldtz
      if defined $oldtz;
}

# This is for the day/week/month/year for the
# device
sub do_html($) {
    my ($tgt) = @_;

    my @day   = do_image( $tgt, 'day' );
    my @week  = do_image( $tgt, 'week' );
    my @month = do_image( $tgt, 'month' );
    my @year  = do_image( $tgt, 'year' );

    http_headers( 'text/html', $tgt->{config} );
    print qq\
        <!DOCTYPE html>
        <HTML>
        <HEAD>
        <LINK rel="stylesheet" type="text/css" href="${opsview_base}/stylesheets/mrtg.css" />
        <link rel="stylesheet" type="text/css" href="/stylesheets/ui-opsview/jquery-ui-1.8.18.custom.css" />
        <link rel="stylesheet" type="text/css" href="/stylesheets/navmenu/navigation.css" />
        <!--[if lt IE 9]>
        <link rel="stylesheet" type="text/css" href="/stylesheets/navmenu/ie/ie.css" />
        <![endif]-->
        <link rel="stylesheet" type="text/css" href="${opsview_base}/stylesheets/custom.css" />
        <script type="text/javascript" src="/javascript/jquery-1.7.1.min.js"></script>
        <script type="text/javascript" src="/javascript/jquery-ui-1.8.18.custom.min.js"></script>
        <script type="text/javascript" src="/javascript/jquery.placeholder.min.js"></script>
        <TITLE>
    \;

    print $tgt->{title} if defined $tgt->{title};
    print "</TITLE>\n";

    html_comments( $tgt, 'd', @{ $day[0] } )   if $#day != -1;
    html_comments( $tgt, 'w', @{ $week[0] } )  if $#week != -1;
    html_comments( $tgt, 'm', @{ $month[0] } ) if $#month != -1;
    html_comments( $tgt, 'y', @{ $year[0] } )  if $#year != -1;

    print $tgt->{addhead} if defined $tgt->{addhead};

    print qq[
        </head>
        $tgt->{bodytag}
        <div id="opsview_menu" style="height:76px">
            <div id="opsview_banner">
                <img src="/images/opsview4-logo.png" alt="Opsview V4 logo" />
            </div>
        </div>
        <script type="text/javascript">
            jQuery(document).ready(function(){
                jQuery('#opsview_menu').load('/navmenu/menu_standalone');
            });
        </script>
        <div id="content">
    ];

    print $tgt->{pagetop} if defined $tgt->{pagetop};

    unless ( defined $tgt->{options}{noinfo} ) {
        my @st = stat $tgt->{rrd};

        print "<HR>\nThe statistics were last updated ",
          strftime( "<B>%A, %d %B, %H:%M:%S %Z</B>\n", localtime( $st[9] ) );
    }

    my $dayavg = $tgt->{config}->{interval};

    html_graph( $tgt, 'day',   'Daily',   $dayavg . ' Minute', \@day );
    html_graph( $tgt, 'week',  'Weekly',  '30 Minute',         \@week );
    html_graph( $tgt, 'month', 'Monthly', '2 Hour',            \@month );
    html_graph( $tgt, 'year',  'Yearly',  '1 Day',             \@year );

    unless ( defined $tgt->{options}{nolegend} ) {
        print <<EOF;
<HR>
<table WIDTH=500 BORDER=0 CELLPADDING=4 CELLSPACING=0>
EOF
        print <<EOF unless ( $tgt->{options}{noi} );
    <tr>
	<td ALIGN=RIGHT><font SIZE=-1 COLOR="$tgt->{col1}">
		<b>$tgt->{colname1} ###</b></font></td>
	<td><font SIZE=-1>$tgt->{legend1}</font></td>
    </tr>
EOF
        print <<EOF unless ( $tgt->{options}{noo} );
    <tr>
	<td ALIGN=RIGHT><font SIZE=-1 COLOR="$tgt->{col2}">
		<b>$tgt->{colname2} ###</b></font></td>
	<td><font SIZE=-1>$tgt->{legend2}</font></td>
    </tr>
EOF
        if ( $tgt->{withpeak} ne '' ) {
            print <<EOF unless ( $tgt->{options}{noi} );
    <tr>
	<td ALIGN=RIGHT><font SIZE=-1 COLOR="$tgt->{col3}">
		<b>$tgt->{colname3} ###</b></font></td>
	<td><font SIZE=-1>$tgt->{legend3}</font></td>
    </tr>
EOF
            print <<EOF unless ( $tgt->{options}{noo} );
    <tr>
	<td ALIGN=RIGHT><font SIZE=-1 COLOR="$tgt->{col4}">
		<b>$tgt->{colname4} ###</b></font></td>
	<td><font SIZE=-1>$tgt->{legend4}</font></td>
    </tr>
EOF
        }
        print <<EOF;
    </table>
EOF
    }

    print $tgt->{pagefoot} if defined $tgt->{pagefoot};
    print '</div>', footer(), '</body></html>';

}

sub footer {
    q[
    <div id="footer">
        <p>Opsview is supported and certified by Opsview Limited</p>
        <p>&copy; <a href="http://www.opsview.com/">Opsview Limited</a> 2013 All Rights Reserved</p>
    </div>
    ];
}

sub html_comments($$@) {
    my ( $tgt, $letter, @val ) = @_;

    return if $#val == -1;

    unless ( $tgt->{options}{noi} ) {
        print "<!-- maxin $letter ", $val[1], " -->\n";
        print "<!-- avin $letter ",  $val[3], " -->\n";
        print "<!-- cuin $letter ",  $val[5], " -->\n";
    }
    unless ( $tgt->{options}{noo} ) {
        print "<!-- maxout $letter ", $val[0], " -->\n";
        print "<!-- avout $letter ",  $val[2], " -->\n";
        print "<!-- cuout $letter ",  $val[4], " -->\n";
    }
}

sub html_graph($$$$$) {
    my ( $tgt, $ext, $freq, $period, $params ) = @_;

    return unless defined $tgt->{$ext};

    my @values = @{ $params->[0] };
    my $x      = $params->[1];
    my $y      = $params->[2];

    $x *= $tgt->{xzoom} if defined $tgt->{xzoom};
    $y *= $tgt->{yzoom} if defined $tgt->{yzoom};

    my $kilo = $tgt->{kilo};
    my @kmg = split( ',', $tgt->{kmg} );

    my $fmt;
    if ( defined $tgt->{options}{integer} ) {
        $fmt = '%d';
    }
    else {
        $fmt = '%.1f';
    }

    my @percent = do_percent( $tgt, \@values );
    my @relpercent = do_relpercent( $tgt, \@values );

    my @nv;
    for my $val (@values) {
        if ( @kmg == 0 ) { # kMG[target]: <empty>
            push @nv, sprintf( $fmt, $val );
            next;
        }
        for my $si (@kmg) {
            if ( $val < 10000 ) {
                push @nv, sprintf( $fmt, $val ) . " $si";
                last;
            }
            $val /= $kilo;
        }
    }
    @values = @nv;

    print "<HR>\n<B>\`$freq\' Graph ($period Average)</B><BR>\n";

    print '<IMG SRC="', $tgt->{url}, '-', $ext, '.' . $imagetype . '" WIDTH=',
      $x, ' HEIGHT=', $y, ' ALT="', $freq, ' Graph" VSPACE=10 ALIGN=TOP><BR>',
      "\n";
    print '<TABLE CELLPADDING=0 CELLSPACING=0>';
    print
      <<EOF if defined( $tgt->{legendi} ) && $tgt->{legendi} ne '' && defined( $tgt->{options} ) && defined( $tgt->{options}{noi} ) && !$tgt->{options}{noi};
    <TR>
	<TD ALIGN=RIGHT><SMALL>Max <FONT COLOR="$tgt->{col1}">$tgt->{legendi}</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$values[1]$tgt->{shortlegend}$percent[1]</SMALL></TD>
	<TD WIDTH=5></TD>
	<TD ALIGN=RIGHT><SMALL>Average <FONT COLOR="$tgt->{col1}">$tgt->{legendi}</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$values[3]$tgt->{shortlegend}$percent[3]</SMALL></TD>
	<TD WIDTH=5></TD>
	<TD ALIGN=RIGHT><SMALL>Current <FONT COLOR="$tgt->{col1}">$tgt->{legendi}</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$values[5]$tgt->{shortlegend}$percent[5]</SMALL></TD>
    </TR>
EOF
    print
      <<EOF if defined( $tgt->{legendo} ) && $tgt->{legendo} ne '' && defined( $tgt->{options} ) && defined( $tgt->{options}{noo} ) && !$tgt->{options}{noo};
    <TR>
	<TD ALIGN=RIGHT><SMALL>Max <FONT COLOR="$tgt->{col2}">$tgt->{legendo}</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$values[0]$tgt->{shortlegend}$percent[0]</SMALL></TD>
	<TD WIDTH=5></TD>
	<TD ALIGN=RIGHT><SMALL>Average <FONT COLOR="$tgt->{col2}">$tgt->{legendo}</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$values[2]$tgt->{shortlegend}$percent[2]</SMALL></TD>
	<TD WIDTH=5></TD>
	<TD ALIGN=RIGHT><SMALL>Current <FONT COLOR="$tgt->{col2}">$tgt->{legendo}</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$values[4]$tgt->{shortlegend}$percent[4]</SMALL></TD>
EOF
    if ( defined $tgt->{options}{dorelpercent} ) {
        print <<"EOF";
    </TR><TR>
	<TD ALIGN=RIGHT><SMALL>Max <FONT COLOR="$tgt->{col5}">&nbsp;Percentage:</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$relpercent[0]</SMALL></TD>
	<TD WIDTH=5></TD>
	<TD ALIGN=RIGHT><SMALL>Average <FONT COLOR="$tgt->{col5}">&nbsp;Percentage:</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$relpercent[1]</SMALL></TD>
	<TD WIDTH=5></TD>
	<TD ALIGN=RIGHT><SMALL>Current <FONT COLOR="$tgt->{col5}">&nbsp;Percentage:</FONT></SMALL></TD>
	<TD ALIGN=RIGHT><SMALL>&nbsp;$relpercent[2]</SMALL></TD>
EOF
    }
    print <<'EOF';
    </TR>
</TABLE>
EOF
}

sub do_percent($$) {
    my ( $tgt, $values ) = @_;

    my @percent = ( '', '', '', '', '', '' );

    return @percent if defined $tgt->{options}{nopercent};

    for my $val ( 0 .. $#$values ) {
        my $mx = ( $val % 2 == 1 ) ? $tgt->{maxbytes1} : $tgt->{maxbytes2};
        next unless defined $mx;
        my $p = sprintf( "%.1f", $values->[$val] * 100 / $mx );
        $percent[$val] = ' (' . $p . '%)';
    }

    @percent;
}

sub do_relpercent($$) {
    my ( $tgt, $values ) = @_;

    my @percent = ( '', '', '' );

    return @percent unless defined $tgt->{options}{dorelpercent};

    for my $val ( 0 .. 2 ) {
        $percent[$val] = sprintf( "%.1f",
            $values->[ 2 * $val + 1 ] * 100 / $values->[ 2 * $val ] )
          if $values->[ 2 * $val ] > 0;
        $percent[$val] ||= 0;
        $percent[$val] .= ' %';
    }

    @percent;
}

sub http_headers {
    my ( $content_type, $cfg, $no_refresh ) = @_;

    print <<"EOF";
Content-Type: $content_type
Pragma: no-cache
EOF
    print "Refresh: $cfg->{refresh}\n" unless $no_refresh;

    # Expires header calculation stolen from CGI.pm
    print strftime(
        "Expires: %a, %d %b %Y %H:%M:%S GMT\n",
        gmtime( time + 60 * $cfg->{interval} )
    );

    print "\n";
}

sub do_image($$) {
    my ( $target, $ext ) = @_;

    my $file = $target->{$ext};

    return unless defined $file;

    # Now the vertical rule at the end of the day
    my @t = localtime(time);
    $t[0] = $t[1] = $t[2] = 0;

    my $seconds;
    my $oldsec;
    my $back;
    my $xgrid;

    my $unscaled;
    my $withpeak;

    my $noi = 1 if $target->{options}{noi};
    my $noo = 1 if $target->{options}{noo};

    if ( $ext eq 'day' ) {
        $seconds  = timelocal(@t);
        $back     = 30 * 3600;                      # 30 hours
        $oldsec   = $seconds - 86400;
        $unscaled = 1 if $target->{unscaled} =~ /d/;
        $withpeak = 1 if $target->{withpeak} =~ /d/;

        # We need this only for day graph. The other ones
        # are magically correct.
        $xgrid = 'HOUR:1:HOUR:6:HOUR:2:0:' . $percent_h;
    }
    elsif ( $ext eq 'week' ) {
        $seconds = timelocal(@t);
        $t[6] = ( $t[6] + 6 ) % 7;
        $seconds -= $t[6] * 86400;
        $back     = 8 * 86400;                      # 8 days
        $oldsec   = $seconds - 7 * 86400;
        $unscaled = 1 if $target->{unscaled} =~ /w/;
        $withpeak = 1 if $target->{withpeak} =~ /w/;
    }
    elsif ( $ext eq 'month' ) {
        $t[3]    = 1;
        $seconds = timelocal(@t);
        $back    = 36 * 86400;            # 36 days
        $oldsec  = $seconds - 30 * 86400; # FIXME (the right # of days!!)
        $unscaled = 1 if $target->{unscaled} =~ /m/;
        $withpeak = 1 if $target->{withpeak} =~ /m/;
    }
    elsif ( $ext eq 'year' ) {
        $t[3]    = 1;
        $t[4]    = 0;
        $seconds = timelocal(@t);
        $back    = 396 * 86400;            # 365 + 31 days
        $oldsec  = $seconds - 365 * 86400; # FIXME (the right # of days!!)
        $unscaled = 1 if $target->{unscaled} =~ /y/;
        $withpeak = 1 if $target->{withpeak} =~ /y/;
    }
    else {
        print_error( "Unknown file extension: $ext" );
    }

    my @local_args;

    if ($unscaled) {
        @local_args = ( '-u', $target->{maxbytes1} );
        push @local_args, '--rigid' unless defined $target->{absmax};
    }

    if ($xgrid) {
        push @local_args, '-x', $xgrid;
    }

    my @local_args_end;

    if ($withpeak) {
        push @local_args_end, 'LINE1:maxin' . $target->{col3} . ':MaxIn'
          unless $noi;
        push @local_args_end, 'LINE1:maxout' . $target->{col4} . ':MaxOut'
          unless $noo;
    }

    my @rv =
      RRDs::graph( $file, '-s', "-$back", @local_args, @{ $target->{args} },
        "VRULE:$oldsec#ff0000", "VRULE:$seconds#ff0000", @local_args_end );

    my $rrd_error = RRDs::error;
    print_error("RRDs::graph failed, $rrd_error") if defined $rrd_error;

    # In array context just return the values
    if (wantarray) {
        if ( defined $target->{factor} ) {
            @{ $rv[0] } = map { $_ * $target->{factor} } @{ $rv[0] };
        }
        if ($noi) {
            return ( [ $rv[0][0], 0, $rv[0][1], 0, $rv[0][2], 0 ], $rv[1],
                $rv[2] );
        }
        elsif ($noo) {
            return ( [ 0, $rv[0][0], 0, $rv[0][1], 0, $rv[0][2] ], $rv[1],
                $rv[2] );
        }
        else {
            return @rv;
        }
    }

    # Not in array context ==> print out the PNG file.
    open PNG, "<$file" or print_error( "Can't open $file: $!" );

    binmode PNG;

    http_headers( "image/$imagetype", $target->{config} );

    my $buf;

    # could be sendfile in Linux ;-)
    while ( sysread PNG, $buf, 8192 ) {
        print $buf;
    }
    close PNG;
}

sub common_args($$$) {
    my ( $name, $target, $q ) = @_;

    return @{ $target->{args} } if defined @{ $target->{args} };

    my $noi = 1 if $target->{options}{noi};
    my $noo = 1 if $target->{options}{noo};

    $target->{name} = $name;

    $target->{directory} = ''
      unless defined $target->{directory};

    my $tdir = $target->{directory};
    $tdir .= '/'
      unless $tdir eq '' || $tdir =~ /\/$/;

    $target->{url} = mrtg_base_url($q) . $tdir . $name;

    my $cfg = $target->{config};

    my $dir = $cfg->{workdir};
    $dir = $cfg->{logdir}
      if defined $cfg->{logdir};

    $target->{rrd} = $dir . '/' . $tdir . $name . '.rrd';

    %{ $target->{options} } = ()
      unless defined %{ $target->{options} };

    $dir = $cfg->{workdir};
    $dir = $cfg->{imagedir}
      if defined $cfg->{imagedir};

    $target->{suppress} ||= '';

    $target->{day} = $dir . '/' . $tdir . $name . '-day.' . $imagetype
      unless $target->{suppress} =~ /d/;
    $target->{week} = $dir . '/' . $tdir . $name . '-week.' . $imagetype
      unless $target->{suppress} =~ /w/;
    $target->{month} = $dir . '/' . $tdir . $name . '-month.' . $imagetype
      unless $target->{suppress} =~ /m/;
    $target->{year} = $dir . '/' . $tdir . $name . '-year.' . $imagetype
      unless $target->{suppress} =~ /y/;

    $target->{maxbytes1} = $target->{maxbytes}
      if defined $target->{maxbytes} && !defined $target->{maxbytes1};

    $target->{maxbytes2} = $target->{maxbytes1}
      if defined $target->{maxbytes1} && !defined $target->{maxbytes2};

    my @args = ();

    push @args, '--lazy', '-c', 'FONT#000000', '-c', 'MGRID#000000', '-c',
      'FRAME#000000', '-g', '-l', '0';

    $target->{background} = '#f5f5f5'
      unless defined $target->{background};

    push @args, '-c', 'BACK' . $target->{background};

    push @args, '-c', 'SHADEA' . $target->{background}, '-c',
      'SHADEB' . $target->{background}
      if defined $target->{options}{noborder};

    if ( defined $target->{options}{noarrow} ) {
        push @args, '-c', 'ARROW' . $target->{background};
    }
    else {
        push @args, '-c', 'ARROW#000000';
    }

    push @args, '-b', $target->{kilo}
      if defined $target->{kilo};

    if ( defined $target->{xsize} ) {
        if ( defined $target->{xscale} ) {
            push @args, '-w', $target->{xsize} * $target->{xscale};
        }
        else {
            push @args, '-w', $target->{xsize};
        }
    }

    if ( defined $target->{ysize} ) {
        if ( defined $target->{yscale} ) {
            push @args, '-h', $target->{ysize} * $target->{yscale};
        }
        else {
            push @args, '-h', $target->{ysize};
        }
    }

    my $scale = 1;

    if ( defined $target->{options}->{perminute} ) {
        $scale *= 60;
    }
    elsif ( defined $target->{options}->{perhour} ) {
        $scale *= 3600;
    }

    if ( defined $target->{options}->{bits} ) {
        $scale *= 8;
        $target->{ylegend} = 'Bits per second'
          unless defined $target->{ylegend};
        $target->{legend1} = 'Incoming Traffic in Bits per Second'
          unless defined $target->{legend1};
        $target->{legend2} = 'Outgoing Traffic in Bits per Second'
          unless defined $target->{legend2};
        $target->{legend3} = 'Peak Incoming Traffic in Bits per Second'
          unless defined $target->{legend3};
        $target->{legend4} = 'Peak Outgoing Traffic in Bits per Second'
          unless defined $target->{legend4};
        $target->{shortlegend} = 'b/s'
          unless defined $target->{shortlegend};
    }
    else {
        $target->{ylegend} = 'Bytes per second'
          unless defined $target->{ylegend};
        $target->{legend1} = 'Incoming Traffic in Bytes per Second'
          unless defined $target->{legend1};
        $target->{legend2} = 'Outgoing Traffic in Bytes per Second'
          unless defined $target->{legend2};
        $target->{legend3} = 'Peak Incoming Traffic in Bytes per Second'
          unless defined $target->{legend3};
        $target->{legend4} = 'Peak Outgoing Traffic in Bytes per Second'
          unless defined $target->{legend4};
        $target->{shortlegend} = 'B/s'
          unless defined $target->{shortlegend};
    }

    if ( $scale > 1 ) {
        push @args, "DEF:in0=$target->{rrd}:ds0:AVERAGE",
          "CDEF:in=in0,$scale,*", "DEF:maxin0=$target->{rrd}:ds0:MAX",
          "CDEF:maxin=maxin0,$scale,*"
          unless $noi;
        push @args, "DEF:out0=$target->{rrd}:ds1:AVERAGE",
          "CDEF:out=out0,$scale,*", "DEF:maxout0=$target->{rrd}:ds1:MAX",
          "CDEF:maxout=maxout0,$scale,*"
          unless $noo;
    }
    else {
        push @args, "DEF:in=$target->{rrd}:ds0:AVERAGE",
          "DEF:maxin=$target->{rrd}:ds0:MAX"
          unless $noi;
        push @args, "DEF:out=$target->{rrd}:ds1:AVERAGE",
          "DEF:maxout=$target->{rrd}:ds1:MAX"
          unless $noo;
    }

    my $i = 1;
    for my $coltext ( split( /,/, $target->{colours} ) ) {
        my ( $text, $rgb ) = ( $coltext =~ /^([^#]+)(#[0-9a-fA-F]{6})$/ );
        $target->{ 'col' . $i }     = $rgb;
        $target->{ 'colname' . $i } = $text;
        $i++;
    }

    push @args, '-v', $target->{ylegend};

    push @args, 'AREA:in' . $target->{col1} . ':In',
      unless $noi;
    push @args, 'LINE2:out' . $target->{col2} . ':Out'
      unless $noo;

    push @args, 'PRINT:out:MAX:%.1lf'     unless $noo;
    push @args, 'PRINT:in:MAX:%.1lf'      unless $noi;
    push @args, 'PRINT:out:AVERAGE:%.1lf' unless $noo;
    push @args, 'PRINT:in:AVERAGE:%.1lf'  unless $noi;
    push @args, 'PRINT:out:LAST:%.1lf'    unless $noo;
    push @args, 'PRINT:in:LAST:%.1lf'     unless $noi;

    if ( defined $target->{maxbytes1} ) {
        $target->{maxbytes1} *= $scale;
        push @args, 'HRULE:' . $target->{maxbytes1} . '#cc0000';
    }

    if ( defined $target->{maxbytes2} ) {
        $target->{maxbytes2} *= $scale;
        push @args, 'HRULE:' . $target->{maxbytes2} . '#cccc00'
          if $target->{maxbytes2} != $target->{maxbytes1};
    }

    @{ $target->{args} } = @args;

    @args;
}

sub try_read_config($) {
    my ($prefix) = (@_);
    $prefix =~ s/\/[^\/]*$//;

    # Verify the version of RRDtool:
    if ( !defined $RRDs::VERSION || $RRDs::VERSION < 1.000331 ) {
        print_error(
            "Please install more up-to date RRDtool - need at least 1.000331"
        );
    }

    my $read_cfg;
    if ( !defined $config_time ) {
        $read_cfg = 1;
    }
    else {
        for my $file (@all_config_files) {
            my @stat = stat $file;
            if ( $config_time < $stat[9] ) {
                $read_cfg = 1;
                last;
            }
        }
    }

    return unless $read_cfg;

    my %defaults = (
        xsize   => 400,
        ysize   => 100,
        kmg     => ',k,M,G,T,P',
        kilo    => 1000,
        bodytag => "<BODY BGCOLOR=#ffffff>\n",
        colours =>
          'GREEN#00cc00,BLUE#0000ff,DARK GREEN#006600,MAGENTA#ff00ff,AMBER#ef9f4f',
        legendi   => '&nbsp;In:',
        legendo   => '&nbsp;Out:',
        unscaled  => '',
        withpeak  => '',
        directory => '',
    );

    %targets = ();

    @all_config_files = @config_files;

    my $order = 0;
    for my $cfgfile (@config_files) {
        %{ $targets{_} }   = %defaults;
        %{ $targets{'^'} } = ();
        %{ $targets{'$'} } = ();

        my $cfgref = {
            refresh  => 300,
            interval => 5,
            icondir  => $prefix
        };

        read_mrtg_config( $cfgfile, \%defaults, $cfgref, \$order );
    }

    delete $targets{'^'};
    delete $targets{_};
    delete $targets{'$'};

    parse_directories();

    $config_time = time;
}

sub read_mrtg_config($$$$);

sub read_mrtg_config($$$$) {
    my ( $file, $def, $cfgref, $order ) = @_;

    my %defaults = %$def;

    my @lines;

    open( CFG, "<$file" ) || print_error( "Cannot open config file: $!" );
    while (<CFG>) {
        chomp;     # remove newline
        s/\s+$//;  # remove trailing space
        s/\s+/ /g; # collapse white spaces to ' '
        next if /^ *\#/; # skip comment lines
        next if /^\s*$/; # skip empty lines
        if (/^ \S/) {    # multiline options
            $lines[$#lines] .= $_;
        }
        else {
            push @lines, $_;
        }
    }
    close CFG;

    foreach (@lines) {
        if (/^\s*([\w\d]+)\[(\S+)\]\s*:\s*(.*)$/) {
            my ( $tgt, $opt, $val ) = ( lc($2), lc($1), $3 );
            unless ( exists $targets{$tgt} ) {

                # pre-set defaults constructed on all of ^, _, and $
                for my $key ( %{ $targets{'^'} } ) {
                    $targets{$tgt}{$key} = $targets{'^'}{$key};
                }
                for my $key ( %{ $targets{'$'} } ) {
                    $targets{$tgt}{$key} .= $targets{'$'}{$key};
                }

                # WARNING: Tobi explicitly said that when all ^, _, and $
                # options are set, the result should be just the value
                # of the _ option (when the option itself is not explicitly
                # defined. I do not agree with him here but I respect this
                # and will try to be compatible with MRTG.
                for my $key ( %{ $targets{'_'} } ) {
                    $targets{$tgt}{$key} = $targets{'_'}{$key};
                }

                # anonymous hash ref - need copy, not ref
                delete $targets{$tgt}{options};

                # The same as above - we need to create this
                # based on [^], [_], and [$] values
                %{ $targets{$tgt}{options} } = ();
                %{ $targets{$tgt}{options} } = %{ $targets{'^'}{options} }
                  if defined $targets{'^'}{options};
                %{ $targets{$tgt}{options} } =
                  ( %{ $targets{$tgt}{options} }, %{ $targets{'_'}{options} } )
                  if defined $targets{'_'}{options};
                %{ $targets{$tgt}{options} } =
                  ( %{ $targets{$tgt}{options} }, %{ $targets{'$'}{options} } )
                  if defined $targets{'$'}{options};

                $targets{$tgt}{order}  = ++$$order;
                $targets{$tgt}{config} = $cfgref;
            }
            if ( $tgt eq '_' && $val eq '' ) {
                if ( defined $defaults{$opt} ) {
                    $targets{_}{$opt} = $defaults{$opt};
                }
                else {
                    delete $targets{_}{$opt};
                }
            }
            elsif ( ( $tgt eq '^' || $tgt eq '$' ) && $val eq '' ) {
                delete $targets{$tgt}{$opt};
            }
            elsif ( $opt eq 'options' ) {

                # Do not forget defaults [^] and [$]
                delete $targets{$tgt}{options};
                %{ $targets{$tgt}{options} } = %{ $targets{'^'}{options} }
                  if defined $targets{'^'}{options};
                $val = lc($val);
                map { $targets{$tgt}{options}{$_} = 1 }
                  ( $val =~ m/([a-z]+)/g );
                %{ $targets{$tgt}{options} } =
                  ( %{ $targets{$tgt}{options} }, %{ $targets{'$'}{options} } )
                  if defined $targets{'$'}{options};
            }
            else {
                my $pre = $targets{'^'}{$opt}
                  if defined $targets{'^'}{$opt};
                $pre ||= '';
                $targets{$tgt}{$opt} = $pre . $val;
                $targets{$tgt}{$opt} .= $targets{'$'}{$opt}
                  if defined $targets{'$'}{$opt};
            }
            next;
        }
        elsif (/^Include\s*:\s*(\S*)$/) {
            push @all_config_files, $1;
            read_mrtg_config( $1, $def, $cfgref, $order );
            next;
        }
        elsif (/^([\w\d]+)\s*:\s*(\S.*)$/) {
            my ( $opt, $val ) = ( lc($1), $2 );
            $cfgref->{$opt} = $val;
            next;
        }
        print_error( "Parse error in $file near $_" );
    }

    if ( defined $cfgref->{pathadd} ) {
        $ENV{PATH} .= ':' . $cfgref->{pathadd};
    }

    #	if (defined $cfgref->{libadd}) {
    #		use lib $cfgref->{libadd}
    #	}
}

sub parse_directories {
    %directories = ();

    # FIXME: the sort is expensive
    for my $name (
        sort { $targets{$a}{order} <=> $targets{$b}{order} }
        keys %targets
      )
    {
        my $dir = $targets{$name}{directory}
          if defined $targets{$name}{directory};
        $dir = '' unless defined $dir;

        my $prefix = '';
        for my $component ( split /\/+/, $dir ) {
            unless ( defined $directories{ $prefix . $component } ) {
                push( @{ $directories{$prefix}{subdir} }, $component );

                # For the directory, get the global parameters
                # from the # config of the first item of the
                # directory:
                $directories{$prefix}{config}  = $targets{$name}{config};
                $directories{$prefix}{bodytag} = $targets{$name}{bodytag};
            }
            $prefix .= $component . '/';
        }
        unless ( defined $directories{$dir} ) {
            $directories{$dir}{config}  = $targets{$name}{config};
            $directories{$dir}{bodytag} = $targets{$name}{bodytag};
            $directories{$dir}{hosts}   = {};
        }

        push( @{ $directories{$dir}{target} }, $name );
        $name =~ s/_.*$//; # Get just hostname
        $directories{$dir}{hosts}->{$name} = 1;
    }
}

# Prints interface information for a specific host
sub print_host {
    my ( $q, $dir, $host ) = @_;
    my $dir1 = $dir . '/';

    my $custom_time_period;
    $custom_time_period = 1 if ( $q->param('start') );

    http_headers( 'text/html', $directories{$dir}{config},
        $custom_time_period );

    print qq\
        <!DOCTYPE html>
        <HTML>
        <HEAD>
        <TITLE>MRTG graphs for $host</TITLE>
        <LINK rel="stylesheet" type="text/css" href="${opsview_base}/stylesheets/skins/aqua/theme.css" />
        <LINK rel="stylesheet" type="text/css" href="${opsview_base}/stylesheets/mrtg.css" />
        <link rel="stylesheet" type="text/css" href="/stylesheets/ui-opsview/jquery-ui-1.8.18.custom.css" />
        <link rel="stylesheet" type="text/css" href="/stylesheets/navmenu/navigation.css" />
        <!--[if lt IE 9]>
        <link rel="stylesheet" type="text/css" href="/stylesheets/navmenu/ie/ie.css" />
        <![endif]-->
        <link rel="stylesheet" type="text/css" href="${opsview_base}/stylesheets/custom.css" />

        <SCRIPT type="text/javascript" src="${opsview_base}/javascript/calendar.js"></SCRIPT>
        <SCRIPT type="text/javascript" src="${opsview_base}/javascript/calendar-en.js"></SCRIPT>
        <SCRIPT type="text/javascript" src="${opsview_base}/javascript/calendar-setup.js"></SCRIPT>
        <script type="text/javascript" src="/javascript/jquery-1.7.1.min.js"></script>
        <script type="text/javascript" src="/javascript/jquery-ui-1.8.18.custom.min.js"></script>
        <script type="text/javascript" src="/javascript/jquery.placeholder.min.js"></script>
        </HEAD>
        $directories{$dir}{bodytag}
        <div id="opsview_menu" style="height:76px">
            <div id="opsview_banner">
                <img src="/images/opsview4-logo.png" alt="Opsview V4 logo" />
            </div>
        </div>
        <script type="text/javascript">
            jQuery(document).ready(function(){
                jQuery('#opsview_menu').load('/navmenu/menu_standalone');
            });
        </script>
        <div id="content">
    \;

    if ( $directories{$dir}{hosts}->{$host} ) {
        print $q->start_div( { -class => "shadow" } );
        print $q->start_div( { -class => "startendform" } );
        print $q->start_form(
            -name   => "main_form",
            -method => "post",

            # Bit hacky - need to add opsview_base somewhere in there
            -action => mrtg_base_url($q) . "?" . $q->query_string,
        );
        print $q->hidden(
            -name  => "host",
            -value => $host
        );
        print $q->label( { for => "start" }, "Start time:" );
        print $q->textfield(
            {
                -id      => "start",
                -name    => "start",
                -default => (
                    strftime "%Y-%m-%d %H:00",
                    localtime( time - 7 * 60 * 60 * 24 )
                ),
                -size => 18,
            }
        );
        print $q->button(
            {
                -id    => "start_trigger",
                -label => "..."
            }
        );
        print $q->br;
        print $q->label( { for => "end" }, "End time:" );
        print $q->textfield(
            {
                -id      => "end",
                -name    => "end",
                -default => ( strftime "%Y-%m-%d %H:00", localtime ),
                -size    => 18,
            }
        );
        print $q->button(
            {
                -id    => "end_trigger",
                -label => "..."
            }
        );
        print $q->br;
        print $q->submit(
            -class => "buttonSubmit",
            -value => "Submit"
        );
        print $q->end_form;
        print $q->end_div;
        print $q->end_div;

        print $q->script( '
			var dateNow = new Date();
			var dateStart = Date.parseDate(document.getElementById("start").value, "%Y-%m-%d %H:00");
			var dateEnd = Date.parseDate(document.getElementById("end").value, "%Y-%m-%d %H:00");
			function cleanup_dates(cal) {
				var date = cal.date;
				var field = document.getElementById("end");
				if (field == cal.params.inputField) {
					dateEnd = new Date(date);
				} else {
					dateStart = new Date(date);
				}
			}
			function top_of_date(date) {
				date.setHours(0);
				date.setMinutes(0);
				date.setSeconds(0);
				date.setMilliseconds(0);
				return date.getTime();
			}
			function bottom_of_date(date) {
				date.setHours(23);
				date.setMinutes(59);
				date.setSeconds(59);
				date.setMilliseconds(999);
				return date.getTime();
			}
			function constrain_end(date) {
                                if (date.getTime() <= bottom_of_date(dateEnd)) return false;
                                else return true;
			}
			function constrain_start(date) {
				if (date.getTime() < top_of_date(dateStart) ||
					date.getTime() > dateNow) return true;
				else return false;
			}
			Calendar.setup(
			{
			inputField  : "start",
			ifFormat    : "%Y-%m-%d %H:00",
			weekNumbers : false,
			button      : "start_trigger",
			range       : [dateNow.getFullYear()-1, dateNow.getFullYear()],
			showsTime   : true,
			onUpdate    : cleanup_dates,
			dateStatusFunc: constrain_end
			} );
			Calendar.setup(
			{
			inputField  : "end",
			ifFormat    : "%Y-%m-%d %H:00",
			weekNumbers : false,
			button      : "end_trigger",
			range       : [dateNow.getFullYear()-1, dateNow.getFullYear()],
			showsTime   : true,
			onUpdate    : cleanup_dates,
			dateStatusFunc: constrain_start
			} );
			' );

        print $q->start_div( { -id => "banner" } );
        print "<H1>Interface statistics for $host</H1>";

        print <<EOF;
<P>Click on graph for more detail on that interface or select custom time period.</P>
EOF

        if ($custom_time_period) {
            print "<H2>Custom time period</H2>";
        }
        else {
            print "<H2>Last 24 hours</H2>";
        }
        print $q->end_div;

        my $ext          = "day";
        my $query_string = "";
        if ($custom_time_period) {
            $ext          = "custom";
            $query_string = "?" . $q->query_string;
        }

        for my $interface_name ( @{ $directories{$dir}{target} } ) {

            # Ignore targets that are not for this host
            next unless $interface_name =~ /^${host}_.*$/;

            # Get interface description, rather than hostname_int
            $_ = $targets{$interface_name}{setenv};
            s/.*MRTG_INT_DESCR="([^"]*)".*/$1/;
            my $description = $_ || $interface_name;

            print <<EOF;
<HR />
<H3>$description</H3>
<A HREF="$interface_name.html">
<IMG WIDTH=493 HEIGHT=140 SRC="$interface_name-$ext.$imagetype$query_string" BORDER=0 ALT="$interface_name" /></A>
<BR />
EOF
        }
    }
    else {
        print "<P>No such host: $host</P>";
    }

    print '</div>', footer(), '</body></html>';
}

# This prints all devices in this directory
sub print_dir($) {
    my ($dir) = @_;

    my $dir1 = $dir . '/';

    http_headers( 'text/html', $directories{$dir}{config} );

    print <<EOF;
<HTML>
<HEAD>
<TITLE>MRTG: Directory $dir1</TITLE>
</HEAD>
EOF
    print $directories{$dir}{bodytag};

    my $subdirs_printed;
    if ( defined @{ $directories{$dir}{subdir} } ) {
        $subdirs_printed = 1;
        print <<EOF;
<H1>MRTG subdirectories in the directory $dir1</H1>

<UL>
EOF
        for my $item ( @{ $directories{$dir}{subdir} } ) {
            print "<LI><A HREF=\"$item/\">$item/</A>\n";
        }

        print "</UL>\n";
    }
    if ( defined @{ $directories{$dir}{target} } ) {
        print "<HR>\n" if defined $subdirs_printed;
        print <<EOF;
<H1>MRTG graphs in the directory $dir1</H1>

<TABLE BORDER=0 WIDTH=100%>
EOF
        my $odd;
        for my $item ( @{ $directories{$dir}{target} } ) {
            my $itemname = $item;
            $itemname = $targets{$item}{title}
              if defined $targets{$item}{title};
            print "    <TR>\n" unless $odd;
            print <<EOF;
   <TD><A HREF="$item.html">$itemname<BR>
	<IMG SRC="$item-day.$imagetype" BORDER=0 ALIGN=TOP VSPACE=10 ALT="$item">
	</A><BR CLEAR=ALL>
   </TD>
EOF
            print "    </TR>\n" if $odd;
            $odd = !$odd;
        }
        print "    </TR>\n</TABLE>\n";
    }

    print footer(), '</body></html>';
}

sub dump_targets() {
    for my $tgt ( keys %targets ) {
        print "Target $tgt:\n";
        for my $opt ( keys %{ $targets{$tgt} } ) {
            if ( $opt eq 'options' ) {
                print "\toptions: ";
                for my $o1 ( keys %{ $targets{$tgt}{options} } ) {
                    print $o1, ",";
                }
                print "\n";
                next;
            }
            print "\t$opt: ", $targets{$tgt}{$opt}, "\n";
        }
    }
}

sub dump_directories {
    print "Directories:\n";

    for my $dir ( keys %directories ) {
        print "Directory $dir:\n";
        for my $item ( @{ $directories{$dir} } ) {
            print "\t$item\n";
        }
    }
}

sub print_error(@) {
    print "Content-Type: text/plain\n\nError: ", join( ' ', @_ ), "\n";
    exit 0;
}

#--BEGIN CGI--
#For CGI, use this:

use CGI;
my $q = new CGI;

# thttpd fix up by Akihiro Sagawa
if ( $q->server_software() =~ m|^thttpd/| ) {
    my $path = $q->path_info();
    $path .= '/' if ( $q->script_name =~ m|/$| );
    $q->path_info($path);
}
elsif ( $q->server_software() =~ m|^HTTP-Request-AsCGI/| ) {
    my $path = $q->path_info();
    $path =~ s/.*mrtg-rrd.cgi//;
    $q->path_info($path);
}

handler($q);

#--END CGI--
#--BEGIN FCGI--
# For FastCGI, uncomment this and comment out the above:
#-# use FCGI;
#-# use CGI;
#-#
#-# my $req = FCGI::Request();
#-#
#-# while ($req->Accept >= 0) {
#-# 	my $q = new CGI;
#-#
#-# 	# thttpd fix up by Akihiro Sagawa
#-# 	if ($q->server_software() =~ m|^thttpd/|) {
#-# 		my $path = $q->path_info();
#-# 		$path .= '/' if ($q->script_name=~ m|/$|);
#-# 		$q->path_info($path);
#-# 	}
#-#
#-# 	handler($q);
#-# }
#--END FCGI--

sub do_custom_image($$) {
    my ( $target, $q ) = @_;

    my ( $start, $end );
    if ( $_ = $q->param('start') ) {
        @_ = /(\d+)-(\d+)-(\d+) (\d+):(\d+)/;
        $start = timelocal( 0, $_[4], $_[3], $_[2], $_[1] - 1, $_[0] );
    }
    else {
        $start = time - 3 * 86400;
    }
    if ( $_ = $q->param('end') ) {
        @_ = /(\d+)-(\d+)-(\d+) (\d+):(\d+)/;
        $end = timelocal( 0, $_[4], $_[3], $_[2], $_[1] - 1, $_[0] );
    }
    else {
        $end = time;
    }

    my @local_args;

    my $file = "/tmp/ton.$$.png";
    my @rv   = RRDs::graph(
        $file,
        '-s', "$start",
        '-e', "$end",
        @local_args,
        @{ $target->{args} },

        #"VRULE:$seconds#ff0000",
    );

    my $rrd_error = RRDs::error;
    print_error("RRDs::graph failed, $rrd_error") if defined $rrd_error;

    # Print out the PNG file.
    open PNG, "<$file" or print_error( "Can't open $file: $!" );

    binmode PNG;

    http_headers( "image/$imagetype", $target->{config} );
    my $buf;

    # could be sendfile in Linux ;-)
    while ( sysread PNG, $buf, 8192 ) {
        print $buf;
    }
    close PNG;

    unlink $file;
}

1;
