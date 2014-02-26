#!/usr/bin/perl
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";

use Test::More qw/no_plan/;
use File::Find;
use Data::Dump qw(dump);
use File::Glob ':glob';
use File::Basename;

my $topdir = $Bin;
$topdir =~ s!/t$!!;

my $error = 0;

package Entry;

use Class::Struct;

struct(
    type  => '$',
    owner => '$',
    group => '$',
    perms => '$',
    dst   => '$',
    src   => '$',
);

1;

package main;

use base "Entry";

# List of files and directories to ignore.
my %filelist = (
    "filelist.in" => {
        atom                                       => 1,
        t                                          => 1,
        patches                                    => 1,
        "nagios-icons"                             => 1,
        "nagios-plugins"                           => 1,
        installer                                  => 1,
        published                                  => 1,
        "build-aux"                                => 1,
        Makefile                                   => 1,
        ".perltidyrc"                              => 1,
        ".rnd"                                     => 1,
        ".subversion"                              => 1,
        snmp                                       => 1,
        sbin                                       => 1,
        libexec                                    => 1,
        etc                                        => 1,
        debian                                     => 1,
        configs                                    => 1,
        var                                        => 1,
        nmis                                       => 1,
        "utils/migrate_initialdb_to_opspacks"      => 1,
        "utils/migrate_initialdb_to_opspacks_test" => 1,
        "import/opspacks/%SUBDIRS%"                => 1,
        "import/opspacks_source"                   => 1,
        "share/mrtg"                               => 1,
        "share/faviconCommunity.ico"               => 1,
        "share/faviconEnterprise.ico"              => 1,
        "bin/profile_dev"                          => 1,
        "bin/debug"                                => 1,
        "bin/fakeslavegen"                         => 1,
        "bin/mrtghtmlgen.pl"                       => 1,
        "bin/rc.opsview.fakeslaves"                => 1,
        "bin/wmic"                                 => 1,
        "version"                                  => 1,
        "version.in"                               => 1,
        "solaris_pkg"                              => 1,
        "bin-protected/"                           => 1,

        # .o files are excluded by svn:ignore automatically, so need to do by hand
        "bin/altinity_distributed_commands.o" => 1,
        "bin/altinity_set_initial_state.o"    => 1,
        "bin/ndomod.o"                        => 1,
        "virtual-appliance"                   => 1,
        "opsview-icons"                       => 1,
        "opsview-images"                      => 1,

        # From Nagios
        "share/js/jquery-1.7.1.min.js" => 1,

        'utils/stress_test'            => 1,
        'utils/perltidyrc'             => 1,
        'utils/vimrc'                  => 1,
        'utils/clean_dev_server'       => 1,
        'utils/dev_test_cleanup'       => 1,
        'utils/generate_host_services' => 1,
        'utils/send_results'           => 1,
        'utils/perl_audit'             => 1,

        # Opsview-Utils-NDOLogsImporter-XS
        "opsview-perl-modules/Opsview-Utils-NDOLogsImporter-XS/MANIFEST" => 1,
        "opsview-perl-modules/Opsview-Utils-NDOLogsImporter-XS/XS.o"     => 1,
        "opsview-perl-modules/Opsview-Utils-NDOLogsImporter-XS/XS.xs"    => 1,
        "opsview-perl-modules/Opsview-Utils-NDOLogsImporter-XS/lib/Opsview/Utils/NDOLogsImporter/XS.pm"
          => 1,
        "opsview-perl-modules/Opsview-Utils-NDOLogsImporter-XS/ppport.h" => 1,
        "opsview-perl-modules/Opsview-Utils-NDOLogsImporter-XS/t/Opsview-Utils-NDOLogsImporter-XS.t"
          => 1,

        # NetFlow files
        "bin/nfanon"   => 1,
        "bin/nfcapd"   => 1,
        "bin/nfdump"   => 1,
        "bin/nfexpire" => 1,
        "bin/nfreplay" => 1,

        # lib/
        "lib/" => 1,

    },
    "nagios-plugins/filelist" => {
        Makefile                              => 1,
        nagiosexchange                        => 1,
        "check_mysql_nagiosdata"              => 1,
        "check_smtprouting"                   => 1,
        "check_snmp_cisco_memutil.v2"         => 1,
        "check_snmp_parameter"                => 1,
        "check_snmp_template"                 => 1,
        "check_snmp_weblogic_idlethreads-8.2" => 1,
        "nagios_smtp_client"                  => 1,
        "nagios_smtp_server"                  => 1,
        "check_memory"                        => 1,
        "check_raid"                          => 1,
    },
);

#plan tests => keys(%filelist) * 6;

sub get_ignore_list ($%) {
    my ( $path, $ignorelist ) = @_;
    my $dir = dirname($path);
    my $git_ignore_path;

    my $current = '';

    if ( -d '.svn' ) {
        open( IGNORE, "-|", "svn propget -R svn:ignore $dir" );
    }
    else {
        open( IGNORE, "-|", "git svn show-ignore" );
        ( $git_ignore_path = $topdir ) =~ s!.*/!/!;
    }
    ok( !$@, "Reading ignore list ok" );
    while ( my $line = <IGNORE> ) {
        next if ( $line =~ m/^\s*$/ );
        next if ( $line =~ m/^#/ );
        if ($git_ignore_path) {

            # chop out anything not in this dir or below since git ignore list
            # is for the whole repo, not just this directory
            next if ( $line !~ $git_ignore_path );
            $line =~ s!^$git_ignore_path/!!;
        }
        chomp($line);
        my $file;
        if ( $line =~ m/(.*) - (.*)/ ) {
            $current = $1 . "/";
            $current = "" if $current eq "./";
            $file    = "${1}/${2}";
        }
        else {
            $file = "${current}${line}";
        }
        foreach my $glob ( bsd_glob($file) ) {
            chomp($glob);
            $glob =~ s/^$dir\///;
            $ignorelist->{$glob} = "from ignore command";
        }
    }
    close(IGNORE);
}

sub check_filelist($@) {
    my ( $path, @exceptions ) = @_;
    my $dir        = dirname($path);
    my $file       = basename($path);
    my %exceptions = map { $_ => 1 } @exceptions, $file, $dir;
    my @entries;
    my %found_files;
    my %missing_filelist;
    my %extra_filelist;
    my $seen_dst = {};

    # read in filelist
    open( FILELIST, "<", $path );
    ok( <FILELIST>, "opened $path" )
      || die( "Failed to open $path: $!" );

    my $entries_ok = 0;
    while ( my $line = <FILELIST> ) {
        next if ( $line =~ /^#/ );
        next if ( $line =~ /^$/ );
        my @line = split( /\s+/, $line );

        if ( $line[0] =~ m/^d$/ ) {

            # stuff all directories into the exceptions list
            $line[3] =~ s!^$dir!!;
            $exceptions{ $line[3] } = "set";
            next;
        }

        my $entry = new Entry;
        my ( $owner, $group ) = split( /[:\.]/, $line[1] );

        $entry->type( $line[0] );
        $entry->owner($owner);
        $entry->group($group);
        $entry->perms( $line[2] );
        $entry->dst( $line[3] );
        $entry->src( $line[4] );

        $seen_dst->{ $line[3] }++;

        unless ( $entry->type
            && $entry->owner
            && $entry->group
            && $entry->perms
            && $entry->dst
            && $entry->src )
        {
            $entries_ok ||= 1;
        }

        push( @entries, $entry );
    }

    ok( $entries_ok == 0, "no malformed filelist entries" );

    close(FILELIST);

    my @duplicates;
    foreach my $k ( keys %$seen_dst ) {
        if ( $seen_dst->{$k} > 1 ) {
            push @duplicates, $k;
        }
    }
    if (@duplicates) {
        fail( "Duplicates: @duplicates" );
    }
    else {
        pass( "No duplicates seen" );
    }

    # read in whats there
    find(
        {
            follow => 0,
            wanted => sub {
                return if ( $File::Find::name =~ m/\.gitignore/ );
                return if ( $File::Find::name =~ m/\.svn/ );
                return if ( $File::Find::name =~ m/\.swp/ );
                return if ( $File::Find::name =~ m!/perl/! );
                return if ( -d $File::Find::name );
                my $file = $File::Find::name;
                $file =~ s!^$dir/!!;
                $found_files{$file} = 1;
              }
        },
        $dir
    );

    ok( %found_files, "directories searched ok" );

    # Now go through all entries and mark them off the found_files, see whats
    # left
    {
        my @found_files;
        foreach my $entry (@entries) {
            if ( !defined( $found_files{ $entry->src } ) ) {
                $extra_filelist{ $entry->src } = 1;
            }
            else {
                push( @found_files, $entry->src );
            }
        }

        # delay deleting until now in case src file is used multiple times
        delete $found_files{$_} foreach (@found_files);
    }

    if (%extra_filelist) {
        fail( "Extra files in filelist" );
        warn( "Extra files in filelist $Bin/../$file:\n",
            dump( sort( keys(%extra_filelist) ) ), "\n" );
    }
    else {
        pass( "No extra files in filelist" );
    }

    FILE: foreach my $file ( sort( keys(%found_files) ) ) {

        #warn("Checking $file") if ($file !~ /(?:snmp|share|nmis|icon)/);
        foreach my $exception ( keys(%exceptions) ) {
            if ( $file =~ m!^$exception! ) {
                next FILE;
            }
            if ( $exception =~ /%SUBDIRS%/ ) {
                ( my $path = $exception ) =~ s/%SUBDIRS%/[^\/]+\/.+/;
                if ( $file =~ m!^$path! ) {
                    next FILE;
                }
            }
        }
        $missing_filelist{$file} = "missing from filelist in $dir";
    }

    if (%missing_filelist) {
        fail( "All files accounted for" );
        warn( "These files are missing:\n",
            dump( sort( keys(%missing_filelist) ) ), "\n" );
        warn( "from the filelist  $topdir/$file\n" );
    }
    else {
        pass( "All files accounted for" );
    }
}

foreach my $path ( sort( keys(%filelist) ) ) {
    get_ignore_list( "$topdir/$path", \%{ $filelist{$path} } );
    check_filelist( "$topdir/$path", keys( %{ $filelist{$path} } ) );
}
