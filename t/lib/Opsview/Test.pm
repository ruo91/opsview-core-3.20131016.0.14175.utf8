package Opsview::Test;

use strict;
use warnings;
use FindBin qw($Bin);

use Test::Perldump::File;

# Default actions
my @actions = qw(stop opsview runtime);

# Only allow db import once
my $imported = 0;

sub import {
    return if $ENV{SKIP_OPSVIEW_TEST_IMPORT};

    my $class = shift;
    @actions = @_ if @_;
    unless ( ( $ARGV[0] && $ARGV[0] eq "nodb" && shift @ARGV )
        || $imported == 1 )
    {
        &setup_db;
    }
    $imported = 1;
    if ( $ARGV[0] && $ARGV[0] eq "resetperldumps" ) {
        Test::Perldump::File->resetperldumps(1);
    }
}

sub setup_db {

    my %actions = map { ( $_ => 1 ) } @actions;

    if ( $actions{stop} ) {

        # Stop opsview first, because db shouldn't be updated during this process
        system("/usr/local/nagios/bin/rc.opsview stop") == 0
          or die "Cannot stop opsview";
    }

    # Restore database
    # Need to go up two levels because opsview-web also calls this
    if ( $actions{opsview} ) {
        system(
            "/usr/local/nagios/bin/db_opsview -t db_restore < $Bin/../../opsview-core/t/var/opsview.test.db"
          ) == 0
          or die "Cannot restore opsview";
    }

    if ( $actions{runtime} ) {
        system(
            "/usr/local/nagios/bin/db_runtime -t db_restore < $Bin/../../opsview-core/t/var/runtime.test.db"
          ) == 0
          or die "Cannot restore runtime";
    }

    if ( $actions{rrds} ) {
        __PACKAGE__->restore_rrds();
    }
}

sub restore_rrds {
    print "Restoring RRDs\n";
    my $rrddir = "/usr/local/nagios/var/rrd";
    system("rm -fr $rrddir/*") == 0
      or die "Cannot delete contents of $rrddir: $!";
    system(
        "cd $rrddir && tar --gzip -xf '$Bin/../../opsview-core/t/var/rrd/dumpedrrds.tar.gz'"
      ) == 0
      or die "Cannot restore rrds";
    require RRDs;
    require File::Next;
    my $files = File::Next::files( "$rrddir" );
    while ( defined( my $file = $files->() ) ) {
        next unless $file =~ /\.dump$/;
        my $rrd = $file;
        $rrd =~ s/\.dump$//;
        RRDs::restore( $file, $rrd, "-f" );
    }
}

sub strip_field_from_hash {
    my ( $class, $field, $hash ) = @_;
    foreach my $k ( keys %$hash ) {
        if ( $k eq $field ) {
            delete $hash->{$field};
        }
        else {
            if ( ref( $hash->{$k} ) eq "HASH" ) {
                $class->strip_field_from_hash( $field, $hash->{$k} );
            }
            elsif ( ref( $hash->{$k} ) eq "ARRAY" ) {
                $class->strip_field_from_array( $field, $hash->{$k} );
            }
        }
    }
}

sub strip_field_from_array {
    my ( $class, $field, $array ) = @_;
    foreach my $a (@$array) {
        if ( ref($a) eq "HASH" ) {
            $class->strip_field_from_hash( $field, $a );
        }
    }
}

# This is similar to Opsview::Web::Controller::Root's dt_formatter, for testing purposes
sub dt_formatter {
    my ($class) = @_;
    my $date_formatter = DateTime::Format::Strptime->new(
        pattern   => "%F %T",
        time_zone => "local"
    );
    my $dt_formatter = sub {
        my $dt = shift;
        $dt->set_formatter($date_formatter);
        $dt->set_time_zone( "local" );
        "$dt";
    };
    $dt_formatter;
}

sub delete_snmptraps {
    require Opsview::Schema;
    my $schema = Opsview::Schema->my_connect;
    $schema->resultset("Servicechecks")->search( { checktype => 4 } )
      ->delete_all;
}

1;
