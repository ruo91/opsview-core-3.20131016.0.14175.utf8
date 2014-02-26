#!/usr/bin/perl
#
# SYNTAX:
my $usage = "upgradedb.pl -u user -p password -h hostname -d database";

#
# DESCRIPTION:
#	Runs upgrade scripts in this directory based on current level of database
#	Options as mysql's for authentication
#
# COPYRIGHT:
#	Copyright (C) 2005 Altinity Limited
#	Copyright is freely given to Ethan Galstad if included in the NDOUtils distribution
#
# LICENCE:
#	GNU GPLv2
#
# NOTE:
# 	The version numbering is not necessarily intuitive. A script called mysql-upgrade-1.3.sql means
# 	that the 1.3 schema needs to run this script.
# 	This affects a lot of the logic in this script

use strict;
use FindBin qw($Bin);
use Getopt::Std;
use DBI;

sub usage {
    print $usage, $/, "\t", $_[0], $/;
    exit 1;
}

my $opts = {};
getopts( "u:p:h:d:", $opts ) or usage "Bad options";

my $database = $opts->{d} || usage "Must specify a database";
my $hostname = $opts->{h} || "localhost";
my $username = $opts->{u} || usage "Must specify a username";
my $password = $opts->{p};
usage "Must specify a password" unless defined $password; # Could be blank

# Connect to database
my $dbh = DBI->connect(
    "DBI:mysql:database=$database;host=$hostname",
    $username, $password, { RaiseError => 1 },
) or die "Cannot connect to database";

# Get current database version
# Version in db table is the "last version applied" rather than "this schema version"
eval { $dbh->do("SELECT * FROM nagios_database_version") };
my $version;
if ($@) {
    print "Can ignore above error",                 $/;
    print "Creating table nagios_database_version", $/;
    $dbh->do( "CREATE TABLE nagios_database_version (version varchar(10))" );
    $dbh->do( "INSERT nagios_database_version VALUES ('1.0')" );
    $version = "1.0";
}
else {
    $version =
      $dbh->selectrow_array( "SELECT version FROM nagios_database_version" );
}

# Read all upgrade scripts in the directory containing this script
# Must be of form mysql-upgrade-{version}.sql
my $upgrades = {};
opendir( SCRIPTDIR, $Bin ) or die "Cannot open dir $Bin";
foreach my $file ( readdir SCRIPTDIR ) {
    next unless $file =~ /^mysql-upgrade-(.*)\.sql/;
    $upgrades->{$1} = $file;
}
closedir SCRIPTDIR;

# Huge dependency that the version numbers are sorted "alphabetically"
# If below is not right, then the upgrade script could be applied in the wrong order
my @ordered_upgrades = sort keys %$upgrades;

my $changes = 0;
foreach my $script_version (@ordered_upgrades) {

    # "gt" is used otherwise when re-run, this will always try to apply the last sql script
    if ( $script_version gt $version ) {
        my $file = $upgrades->{$script_version};
        print "Upgrade required for $script_version", $/;
        my $p = "-p$password" if $password; # Not required if password is blank
        system("mysql -u $username $p -D$database -h$hostname < $Bin/$file")
          == 0
          or die "Upgrade from $file failed";
        $dbh->do(
            "UPDATE nagios_database_version SET version='$script_version'"
        );
        $version = $script_version;
        $changes++;
    }
}

unless ($changes) {
    print "No database updates required. At version $version", $/;
}
