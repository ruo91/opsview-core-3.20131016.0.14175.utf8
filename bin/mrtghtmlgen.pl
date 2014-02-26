#!/usr/bin/perl
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

use File::Find;
use IO::File;
use Net::SNMP 4.1.0 qw(DEBUG_ALL);

@interfacetable        = ();
$noofinterfaces        = 0;
@mrtghosts             = ();
$hosttable             = ();
@interfacecomments     = ();
$noofinterfacecomments = 0;
@filenamearray = (); # temporary array used to hold sorted list of filenames

$config_alias = "MRTG Graphs";

$mrtg           = "/usr/sbin/rrdtool";
$mrtgcfg        = "../etc/mrtg.cfg";
$cfgmaker       = "/usr/local/mrtg/mrtg/bin/cfgmaker";
$imgpath        = "../share/mrtg";
$configfilepath = "../etc";

# $mrtggraphics = "/usr/local/nagios/share/mrtg/";

$noofhosts = 0;

#SNMP
$ifdescr      = ".1.3.6.1.2.1.2.2.1.2.";
$ifspeed      = ".1.3.6.1.2.1.2.2.1.5.";
$ifoperstatus = ".1.3.6.1.2.1.2.2.1.8.";
$version      = "1";
$community    = "public";
$retries      = 0;
$timeout      = 1;

read_interfacecomments();
read_hosttable();
match_hosts();

find sub { parse_filename($_) }, $imgpath;

#@filenamearray = sort @filenamearray;
#foreach $line (@filenamearray) {
#  print "$line\n";
#  parse_filename($line);
#}
generate_html();

sub generate_filename_array {
    my $filename = "@_[0]";
    push( @filenamearray, $filename );
}

sub parse_filename {
    my $hostname  = "";
    my $interface = "";

    my $filename = "@_[0]";
    if ( $filename =~ /.html/ ) {

        my $s1 = $filename;

        # strips 'thumb' attribute from filename and records
        # the fact this is a thumbnail for later
        # breaks remaining filename into base attributes

        $s1 =~ s/.html//g; # removes file extention

        $s1 =~ s/_/ /g;    # replaces '_' with ' ' to make parsing easier

        $s1 =~ /(\S+)/;
        $hostname = $1;
        $s1 =~ s/$hostname//g; # removes hostname from string

        $interface = $s1;
        $hostname  =~ s/ //g;  # removes whitespace
        $interface =~ s/ //g;  # removes whitespace

        # print "hostname: $hostname\n";
        # print "interface: $interface\n";
        if ( $interface eq "" ) {
        }
        else {
            $interfacetable[$noofinterfaces][0] = $hostname;
            $interfacetable[$noofinterfaces][1] = $interface;
            $noofinterfaces++;
        }
    }
}

sub generate_html {
    my $description = "";
    my $speed       = "";
    my $status      = "";
    my $interface   = "";
    my $hostname    = "";
    my @temparray   = ();

    foreach $line (@mrtghosts) {
        @temparray = ();
        $hostname  = $line;

        open HTML, ">$imgpath/$line.html"
          or die "Can't open file $imgpath/$line.html $1";

        print HTML
          "<HEAD><META HTTP-EQUIV=\"Pragma\" CONTENT=\"no-cache\"><META HTTP-EQUIV=\"Expires\" CONTENT=\"-1\"><meta http-equiv=\"REFRESH\" content=\"120; URL=./$line.html\"><link rel=\"stylesheet\" href=\"/nagios/stylesheets/admin.css\"></HEAD>\n";

        print HTML
          "<H1>Interface Statistics for Host $line - (Last 24 Hours)</H1>\n";
        print HTML
          "Click on interface description or graph for more detail.\n<P><HR>\n";

        my $row = 0;
        while ( $row <= $noofinterfaces ) {
            if ( $interfacetable[$row][0] eq $line ) {
                push( @temparray, $interfacetable[$row][1] );
            }
            $row++;
        }
        @temparray = sort { $a <=> $b } @temparray;
        foreach $interface (@temparray) {
            my $hostnameinterface = "$hostname _ $interface";
            $hostnameinterface =~ s/ //g; # removes spaces
                                          # print "$hostnameinterface\n";
            my $tempstring = get_interfacedescr( $hostname, $interface );
            print HTML
              "<H3><A HREF=\"./$hostnameinterface.html\">Interface $interface: $tempstring</A>\n";
            $tempstring = display_interfacecomments( $hostname, $interface );
            if ( $tempstring eq "" ) {
                print HTML
                  "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<A HREF=\"/nagios/cgi-bin/admin_editinterfacecomment.cgi?action=edit&host=$hostname&interface=$interface\"><IMG SRC=\"/nagios/images/comment.gif\" BORDER=0> add</A></H4>\n";
            }
            else {
                print HTML
                  "</H3><A HREF=\"/nagios/cgi-bin/admin_editinterfacecomment.cgi?action=edit&host=$hostname&interface=$interface\"><IMG SRC=\"/nagios/images/comment.gif\" BORDER=0></A><B> $tempstring</B><P>\n";
            }
            $tempfilename = $imgpath . "/" . $hostnameinterface . "-day.png";
            if ( -e "$tempfilename" ) {
                print HTML
                  "<A HREF=\"./$hostnameinterface.html\"><IMG SRC=\"./$hostnameinterface-day.png\" border=0></A>\n";
            }
            else {
                print HTML
                  "No performance information available for this interface.";
            }
            print HTML "<BR><BR><BR><HR>\n";
        }
        print HTML "</HTML>\n";
        close HTML;
    }
}

sub get_interfacedescr {
    my $hostname    = "@_[0]";
    my $interface   = "@_[1]";
    my $description = "";
    my $tempstring  = "";
    my $speed       = "";
    my $status      = "";

    $community = return_snmpcommunity($hostname);

    # Create the SNMP session
    my ( $s, $e ) = Net::SNMP->session(
        -community => $community,
        -hostname  => $hostname,
        -version   => $version,
        -retries   => $retries,
        -timeout   => $timeout,
    );

    # Description

    $tempstring = "$ifdescr$interface";
    if ( !defined( $s->get_request($tempstring) ) ) {
        return 1;
    }
    else {
        foreach ( $s->var_bind_names() ) {
            $description = $s->var_bind_list()->{$_};

            # print "$hostname, community: $community\n";
            # print "$description\n";
        }
    }

    # Speed

    $tempstring = "$ifspeed$interface";
    if ( !defined( $s->get_request($tempstring) ) ) {
        return 1;
    }
    else {
        foreach ( $s->var_bind_names() ) {
            $speed = $s->var_bind_list()->{$_};
            my $mbps = $speed / 1000000;
            if ( $mbps < 1 ) {
                $speed = $speed / 1000;
                $speed = "$speed Kbps";
            }
            else {
                $speed = $mbps;
                $speed = "$speed Mbps";
            }

            # print "Speed: $speed\n";
        }
    }

    # Status

    $tempstring = "$ifoperstatus$interface";
    if ( !defined( $s->get_request($tempstring) ) ) {
        return 1;
    }
    else {
        foreach ( $s->var_bind_names() ) {
            $status = $s->var_bind_list()->{$_};
            if ( $status eq "1" ) {
                $status = "up";
            }
            else {
                $status = "down";
            }

            # print "Status: $status\n";
        }
    }

    $tempstring =
      "$description&nbsp;&nbsp;($speed,&nbsp;current status: $status)";
    return ($tempstring);

}

################################################################
# Reads hosttable.db into array @hosttable                     #
# also calls display_hosttable for each row                    #
################################################################

sub read_hosttable {
    my @temparray = ();
    my $row       = 0;

    open INFILE, "<$configfilepath/hosttable.db"
      or die "Can't open file $configfilepath/hosttable $1";
    @temparray = <INFILE>;
    foreach $line (@temparray) {
        (
            $hosttable[$row][0],  $hosttable[$row][1],  $hosttable[$row][2],
            $hosttable[$row][3],  $hosttable[$row][4],  $hosttable[$row][5],
            $hosttable[$row][6],  $hosttable[$row][7],  $hosttable[$row][8],
            $hosttable[$row][9],  $hosttable[$row][10], $hosttable[$row][11],
            $hosttable[$row][12], $hosttable[$row][13], $hosttable[$row][14],
            $hosttable[$row][15]
        ) = split( /:/, $line );
        $row++;
    }
    close INFILE;
    $noofhosts = $row;
}

################################################################
# Reads interfacetable.db into array @interfacecomments        #
################################################################

sub read_interfacecomments {
    my @temparray = ();
    my $row       = 0;

    open INFILE, "<$configfilepath/interfacetable.db"
      or die "Can't open file $configfilepath/interfacetable $1";
    @temparray = <INFILE>;
    foreach $line (@temparray) {
        (
            $interfacecomments[$row][0],
            $interfacecomments[$row][1],
            $interfacecomments[$row][2]
        ) = split( /:/, $line );
        $row++;
    }
    close INFILE;
    $noofinterfacecomments = $row;
}

################################################################
# Returns comments for given interface                         #
################################################################

sub display_interfacecomments {
    my $hostname  = $_[0];
    my $interface = $_[1];
    my $row       = 0;
    my $comment   = "";

    while ( $row <= $noofinterfacecomments ) {
        if (    $interfacecomments[$row][0] eq $hostname
            and $interfacecomments[$row][1] eq $interface )
        {
            $comment = $interfacecomments[$row][2];
        }
        $row++;
    }
    return ($comment);
}

################################################################
# Populates array @mrtghosts                                   #
################################################################

sub match_hosts {
    my $row       = 0;
    my @temparray = ();
    my $matches   = 0;

    while ( $row <= $noofhosts ) {
        @temparray = split( /,/, $hosttable[$row][10] );
        $matches = 0;
        foreach $line (@temparray) {
            if ( $line eq $config_alias ) {
                $matches = 1;
            }
        }
        if ( $matches == 1 ) {
            if ( $hosttable[$row][0] eq "" ) {
            }
            else {
                push( @mrtghosts, $hosttable[$row][0] );
            }
        }
        $row++;
    }
}

####################################################################
# Returns the SNMP community string for a given hostname / IP      #
####################################################################

sub return_snmpcommunity {
    my $requiredhostname = @_[0];
    my $returncommunity  = "public";
    my $tempcommunity    = "";
    my $temphostname     = "";

    my $row     = 0;
    my $nullval = 0;

    if ( -e "$configfilepath/livehosttable.db" ) {
        open INFILE, "<$configfilepath/livehosttable.db"
          or die "Can't open file $configfilepath/livehosttable.db $1";
        foreach $line (<INFILE>) {
            (
                $temphostname, $nullval, $nullval, $nullval, $nullval, $nullval,
                $nullval, $tempcommunity
            ) = split( /:/, $line );
            if ( $temphostname eq $requiredhostname ) {
                if ( $tempcommunity eq "" ) {
                    $returncommunity = $defaultcommunity;
                }
                else {
                    $returncommunity = $tempcommunity;

                    # print "lookup for $temphostname successful: $tempcommunity\n";
                }
                last;
            }
        }
    }
    else {
    }
    close INFILE;
    return ($returncommunity);
}
