#!/usr/bin/perl

# Originally from insert.pl from Nagiosgraph project, but heavily updated for Opsview
# File:    $Id: insert.pl,v 1.17 2005/10/26 14:42:57 sauber Exp $
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

# Portions Copyright (C) 2003-2010 Opsview Limited

package Opsview::Utils::PerfdatarrdImporter;

use strict;
use lib "/usr/local/nagios/perl/lib", "/usr/local/nagios/lib";
use RRDs;
use RRD::Simple;
use Nagios::Plugin::Performance use_die => 1;
use Utils::Nagiosgraph;
use Data::Dump;
use POSIX;

# Configuration
my $configfile = '/usr/local/nagios/etc/nagiosgraph.conf';

# Main program - change nothing below
my %Config;

# We set this alarm signal handler as RRDs::update has a bug in some scenarios
# that blocks the whole process. This dies out of it and then is caught by the
# eval()
# We must use POSIX calls because this sets the "unsafe" signal as the block
# is within the external library
# WARNING: You cannot use $SIG{ALRM} anywhere else in this program
POSIX::sigaction( SIGALRM,
    POSIX::SigAction->new( sub { die "opsview-timeout" } ) )
  or die "Error setting SIGALRM handler: $!";

sub new {
    my ( $class, $attrs ) = @_;
    my $rootdir = "/usr/local/nagios";
    my $obj     = { %$attrs, };
    bless $obj, $class;
}

sub process_eval_error {
    my ( $self, $error, $filename, $time, $values ) = @_;
    my $debuginfo = "Updating of file=$filename, time=$time, value=$values";
    if ( $error
        =~ /illegal attempt to update using time (\d+) when last update time is (\d+)/
      )
    {
        # TODO: This seems to occur quite a lot. Not sure what the issue is
        # but leaving this will cause the opsviewd.log to fill.
        # We remove it for the moment and have raised DE520 to capture this
        #if ( $1 == $2 ) {
        #    $self->{logger}->info(
        #        "$debuginfo: Updating of same point at $1 - this can be ignored"
        #    );
        #}
        #else {
        #    $self->{logger}->warn( "$debuginfo: Updating error: $error" );
        #}
    }
    elsif ( $error =~ /opsview-timeout/ ) {
        $self->{logger}
          ->error( "$debuginfo: Timeout from rrdupdate. Ignoring this plot" );

        #die "Stop here for testing";
    }
    else {
        $self->{logger}->error( "$debuginfo: UNKNOWN ERROR: $error" );
    }
}

# Read in config file
#
sub readconfig {
    die "config file not found" unless -r $configfile;

    # Read configuration data
    open FH, $configfile;
    while (<FH>) {
        s/\s*#.*//; # Strip comments
        /^(\w+)\s*=\s*(.*?)\s*$/ and do {
            $Config{$1} = $2;
            debug( 5, "INSERT Config $1:$2" );
        };
    }
    close FH;

    # Make sure log file can be written to
    if ( !-e $Config{logfile} ) {
        open F, ">", $Config{logfile};
        close F;
    }
    die "Log file $Config{logfile} not writable" unless -w $Config{logfile};

    # Make sure rrddir exist and is writable
    unless ( -w $Config{rrddir} ) {
        mkdir $Config{rrddir};
        die "rrd dir $Config{rrddir} not writable" unless -w $Config{rrddir};
    }
}

# Parse performance data from input
#
sub parseinput {
    my $data = shift;

    #debug(5, "INSERT perfdata: $data");
    my @d = split( /\|\|/, $data );
    return (
        lastcheck    => $d[0],
        hostname     => $d[1],
        servicedescr => $d[2],
        output       => $d[3],
        perfdata     => $d[4],
    );
}

# Write debug information to log file
#
sub debug {
    my ( $l, $text ) = @_;
    if ( $l <= $Config{debug} ) {
        $l = qw(none critical error warn info debug) [$l];
        $text =~ s/(\w+)/$1 $l:/;
        open LOG, ">>$Config{logfile}";
        print LOG scalar localtime;
        print LOG " $text\n";
        close LOG;
    }
}

# Dump to log the files read from Nagios
#
sub dumpperfdata {
    my %P = @_;
    for ( keys %P ) {
        debug( 4, "INSERT Input $_:$P{$_}" );
    }
}

# Create new rrd databases if necessary
#
sub createrrd {
    my ( $host, $service, $start, $db, $labels ) = @_;
    my ( $f, $v, $t, $ds );

    $f = urlencode("${host}_${service}_${db}") . '.rrd';
    debug( 5, "INSERT Checking $Config{rrddir}/$f" );
    unless ( -e "$Config{rrddir}/$f" ) {
        $ds = "$Config{rrddir}/$f --start $start";
        for (@$labels) {
            ( $v, $t ) = ( $_->[0], $_->[1] );
            my $u = $t eq 'DERIVE' ? '0' : 'U';
            $ds .= " DS:$v:$t:$Config{heartbeat}:$u:U";
        }
        $ds .= " RRA:AVERAGE:0.5:1:600";
        $ds .= " RRA:AVERAGE:0.5:6:700";
        $ds .= " RRA:AVERAGE:0.5:24:775";
        $ds .= " RRA:AVERAGE:0.5:288:797";

        my @ds = split /\s+/, $ds;
        debug( 4, "INSERT RRDs::create $ds" );
        RRDs::create(@ds);
        debug( 2, "INSERT RRDs::create ERR " . RRDs::error ) if RRDs::error;
    }
    return $f;
}

# Use RRDs to update rrd file
#
sub rrdupdate {
    my ( $self, $file, $time, $values ) = @_;
    my $ds;

    my $rrd = RRD::Simple->new(
        file          => $file,
        on_missing_ds => 'add',
    );

    debug( 4, "INSERT RRDs::update " . join ' ', %$values );

    # Need to eval because RRD::Simple will croak on error
    eval {
        alarm 10;
        $rrd->update( $file, $time, %$values );
    };
    alarm 0;
    if ($@) {
        $self->process_eval_error( $@, $file, $time, Data::Dump::dump($values)
        );
    }
}

# See if we can recognize any of the data we got
#
sub parseperfdata {
    my %P = @_;

    $_ =
      "servicedescr:$P{servicedescr}\noutput:$P{output}\nperfdata:$P{perfdata}";
    my $s = evalrules($_);
    if (@$s) {

        # Convert to new hash type here
        # Can assume that only one array is returned (as that is the assumption in earlier insert.pl)
        return convert_map($s);
    }
    else {
        my @metrics = ();
        my $result  = {
            list   => \@metrics,
            dbname => ""
        };
        local $SIG{__DIE__} = 'DEFAULT';
        eval {
            my @a =
              Nagios::Plugin::Performance->parse_perfstring( $P{perfdata} );
            if (@a) {
                foreach my $a (@a) {
                    if ( $a->uom eq 'c' ) {
                        push @metrics,
                          {
                            metric    => $a->clean_label,
                            dstype    => "COUNTER",
                            value     => $a->value,
                            threshold => $a->threshold,
                            uom       => $a->uom
                          };
                    }
                    else {
                        push @metrics,
                          {
                            metric    => $a->clean_label,
                            dstype    => "GAUGE",
                            value     => $a->value,
                            threshold => $a->threshold,
                            uom       => $a->uom
                          };
                    }
                }
            }
        };
        if ($@) {
            debug( 2, "PARSE Cannot parse $_: $@" );
        }
        return $result;
    }
}

# Process all input performance data
#
sub processdata {
    my ( $self, $datalines ) = @_;
    $datalines = [] unless $datalines;
    for my $l (@$datalines) {
        debug( 5, "INSERT processing perfdata: $l" );
        my %P = parseinput($l);
        dumpperfdata(%P);
        my $result = parseperfdata(%P);

        next unless @{ $result->{list} };

        # If old file exists, update the old fashioned way - this can be dropped in Opsview 4
        my $old_filename = urlencode(
            $P{hostname} . "_" . $P{servicedescr} . "_" . $result->{dbname} )
          . '.rrd';
        if ( -e "$Config{rrddir}/$old_filename" ) {
            my $ds = {};
            for ( @{ $result->{list} } ) {

                #$ds->{$_->[0]} = $_->[2] || 0;
                $ds->{ $_->{metric} } = $_->{value};
            }
            $self->rrdupdate( "$Config{rrddir}/$old_filename",
                $P{lastcheck}, $ds );
        }
        else {
            for my $s ( @{ $result->{list} } ) {
                my $rrddir = join( "/",
                    $Config{rrddir},
                    urlencode( $P{hostname} ),
                    urlencode( $P{servicedescr} ),
                    urlencode( $s->{metric} )
                );
                my $values_filename = "$rrddir/value.rrd";
                if ( !-e $values_filename ) {
                    make_rrd_dir(
                        $Config{rrddir},
                        urlencode( $P{hostname} ),
                        urlencode( $P{servicedescr} ),
                        urlencode( $s->{metric} )
                    );
                    my @ds = ( $values_filename, "--start", $P{lastcheck} - 1 );
                    my $u = $s->{dstype} eq 'DERIVE' ? '0' : 'U';
                    push @ds,
                      "DS:value:" . $s->{dstype} . ":$Config{heartbeat}:$u:U",
                      "RRA:AVERAGE:0.5:1:600",  "RRA:AVERAGE:0.5:6:700",
                      "RRA:AVERAGE:0.5:24:775", "RRA:AVERAGE:0.5:288:797";
                    debug( 4, "INSERT RRDs::create @ds" );
                    RRDs::create(@ds);
                    debug( 2, "INSERT RRDs::create ERR " . RRDs::error )
                      if RRDs::error;
                }

                # Update values.rrd
                my @ds = ( $values_filename, "$P{lastcheck}:" . $s->{value} );
                debug( 4, "INSERT RRDs::update @ds" );

                # Set alarm due to possible bug in RRDs::update
                eval {
                    alarm(10);
                    RRDs::update(@ds);
                };
                alarm(0);
                if ($@) {
                    $self->process_eval_error( $@, $values_filename,
                        $P{lastcheck}, $s->{value} );
                }
                debug( 2, "INSERT RRDs::update ERR " . RRDs::error )
                  if RRDs::error;

                # Write uom information
                # We write it each time - possibly in future we should check if the value changes
                my $uom_filename = "$rrddir/uom";
                if ( defined $s->{uom} ) {
                    open UOM, ">", $uom_filename;
                    print UOM $s->{uom};
                    close UOM;
                }

                my %data;
                if ( $s->{threshold} ) {
                    if ( $s->{threshold}->warning->is_set ) {
                        $data{warning_end} = $s->{threshold}->warning->end;
                    }
                    if ( $s->{threshold}->critical->is_set ) {
                        $data{critical_end} = $s->{threshold}->critical->end;
                    }
                }
                if (%data) {

                    # We need to create the rrd. If RRD::Simple does it, will choose large retention periods
                    my $thresholds_rrd = "$rrddir/thresholds.rrd";
                    if ( !-e $thresholds_rrd ) {

                        # We duplicate this section. In future, we may have different parameters for threshold storage
                        my @ds =
                          ( $thresholds_rrd, "--start", $P{lastcheck} - 1 );
                        my $u = $s->{dstype} eq 'DERIVE' ? '0' : 'U';
                        push @ds,
                            "DS:warning_end:"
                          . $s->{dstype}
                          . ":$Config{heartbeat}:$u:U",
                          "DS:critical_end:"
                          . $s->{dstype}
                          . ":$Config{heartbeat}:$u:U", "RRA:AVERAGE:0.5:1:600",
                          "RRA:AVERAGE:0.5:6:700", "RRA:AVERAGE:0.5:24:775",
                          "RRA:AVERAGE:0.5:288:797";
                        debug( 4, "INSERT RRDs::create::thresholds @ds" );
                        RRDs::create(@ds);
                        debug( 2,
                            "INSERT RRDs::create::thresholds ERR "
                              . RRDs::error )
                          if RRDs::error;
                    }

                    # Update thresholds.rrd - use RRD::Simple because may extend in future with other threshold information
                    $self->rrdupdate( $thresholds_rrd, $P{lastcheck}, \%data );
                }
            }
        }
    }
}

sub make_rrd_dir {
    my ( $root, $hostname, $servicename, $metric ) = @_;
    mkdir "$root/$hostname" unless ( -d "$root/$hostname" );
    mkdir "$root/$hostname/$servicename"
      unless ( -d "$root/$hostname/$servicename" );
    mkdir "$root/$hostname/$servicename/$metric"
      unless ( -d "$root/$hostname/$servicename/$metric" );
}

### Main loop
#  - Read config and input
#  - Update rrd files
#  - Create them first if necesary.

readconfig();
debug( 5, 'INSERT nagiosgraph spawned' );

# Read the map file and define a subroutine that parses performance data
open FH, $Config{mapfile};
my $rules = do { local $/; <FH> };
close FH;

# Also look for and load in a xxx.local override file
if ( -f $Config{mapfile} . '.local' ) {
    open my $fh, $Config{mapfile} . '.local';
    $rules .= do { local $/; <$fh>; };
    close $fh;
}
$rules = '
sub evalrules {
  $_=$_[0];
  my @s;
  no strict "subs";
' . $rules . '
  use strict "subs";
  debug(3, "INSERT perfdata not recognized") unless @s;
  return \@s;
}';
undef $@;
eval $rules;
debug( 2, "INSERT Map file eval error: $@" ) if $@;

#processdata(@perfdata);
1;
