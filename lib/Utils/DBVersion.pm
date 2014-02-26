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

package Utils::DBVersion;
use strict;
use Class::Accessor::Fast;
use Carp;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(
    qw(version major_release reason start_time dbh changed schema_table stop_point logfh name)
);

=head1 NAME

Utils::DBVersion - Helper module to calculate database schema versions

=head1 SYNOPSIS

  $db = Utils:DBVersion->new( { dbh => $dbh } );
  if ($db->is_lower("2.7.3")) { 
    ... # Do all your schema changes here
    $db->updated;
  }
  if ($db->changed) {
  }

=head1 DESCRIPTION

Requires a table called "schema_version" with two columns: major_release and version
Works out if a database schema version is lower than a specified one. Will take first two digits 
and find a major_release that matches. If none, will create.
Works by matching the major release in schema_version and then updating there

Only for 3 digit version numbers.

=head1 METHODS

=over 4

=item $db = Utils::DBVersion->new( { dbh => $dbh } )

Initialises an instance of Utils::DBVersion

=cut

sub new {
    my $o = shift->SUPER::new(@_);
    croak "Need a dbh to be set"       unless $o->dbh;
    croak "Name must be set"           unless $o->name;
    $o->schema_table("schema_version") unless $o->schema_table;
    open my $logfh, ">> /usr/local/nagios/var/log/DBVersion.log";
    $o->logfh($logfh);
    my $time = scalar localtime;
    $o->print( "$time: Starting for " . $o->name . "\n" );
    $o;
}

sub DESTROY {
    my $self = shift;
    my $time = scalar localtime;
    if ( $self->name && $self->logfh ) {
        $self->print( "$time: Finished for " . $self->name . "\n" );
    }
    $self->SUPER::DESTROY if $self->can( "SUPER::DESTROY" );
}

sub print {
    my ( $self, @message ) = @_;
    my $message = join( '', @message );
    chomp $message;
    $message .= "\n";
    print $message;
    my $fh = $self->logfh;
    print $fh $message;
}

sub add_notice {
    my $self    = shift;
    my $message = shift;
    $self->dbh->do(
        'INSERT INTO auditlogs SET username="", text=?, notice=1, datetime=NOW()',
        {}, $message
    );
    $self->print($message);
}

=item $db->is_lower("2.7.3")

Returns true if database is lower than 2.7.3. Based on the major release number in the schema_version table.
Will store information so that a $db->updated will update information correctly.

If an override flag exists, will assume the db upgrade step has already been done and will set the new version.

=cut

my $override_dir = "/tmp/opsview_upgrade_override";

sub is_lower {
    my ( $self, $target ) = @_;
    my @t               = split( /[\.-]/, $target );
    my $major_release   = $t[0] . "." . $t[1];
    my $current_version = $self->dbh->selectrow_array(
            "SELECT version FROM "
          . $self->schema_table()
          . " WHERE major_release=$major_release"
    );
    unless ( defined $current_version ) {

        # Check if this major release is larger than all of the existing releases.
        # If not, then forget - must be some old version
        my $releases = $self->dbh->selectcol_arrayref(
            "SELECT major_release FROM " . $self->schema_table() . ""
        );
        if (@$releases) {

            # Need to do this to remove all new style major_release numbers
            # Which caused a problem with the comparisons later
            $releases = [ grep {/^\d+\.\d+$/} (@$releases) ];

            my $flag = scalar @$releases;
            foreach my $major (@$releases) {
                my @a = split( /\./, $major );
                if ( ( $a[0] <=> $t[0] || $a[1] <=> $t[1] ) == -1 ) {
                    $flag--;
                }
                else {
                    last;
                }
            }
            return 0 unless ( $flag == 0 );
        }
        $self->dbh->do(
                "INSERT INTO "
              . $self->schema_table()
              . " (major_release, version) VALUES ('$major_release', '0')"
        );
        $current_version = 0;
    }
    my $rc = $current_version <=> $t[2];
    if ( $rc == -1 ) {
        my $time = scalar localtime;
        $self->print(
            "$time: DB at version " . $major_release . "." . $current_version,
            $/ );
        $self->version( $t[2] );
        $self->major_release($major_release);

        my $override_flag = "$override_dir/" . $self->name . "-$target";
        if ( -e $override_flag ) {
            $self->print(
                "Avoiding upgrade step $target due to override flag - assuming step already done\n"
            );
            $self->updated;
            return 0;
        }
        return 1;
    }
    return 0;
}

=item $db->updated

Updates version tables with the target version as the update has completed

=cut

# The old style is the old x.y.z numbering system which had problems with
# Core and Commercial branches. The new style uses a YYYYMMDDsometext
# to identify the change, which means each change is independent of others
sub updated {
    my ($self) = @_;
    if ( $self->start_time ) {
        $self->updated_new_style;
        $self->start_time(0);
    }
    else {
        $self->updated_old_style;
    }
    $self->changed(1);
}

my $valid_products = {
    "all"        => 1,
    "core"       => 1,
    "commercial" => 1,
};

sub is_installed ($$$) {
    my ( $self, $version_string, $reason, $product ) = @_;

    die "Version string too long - max 16 chars"
      unless length($version_string) <= 16;
    die "Version of form YYYYMMDDtext"
      unless $version_string =~ /^\d\d\d\d\d\d\d\d/;
    die "Reason not set"        unless $reason;
    die "Product not set"       unless $product;
    die "Bad product: $product" unless $valid_products->{$product};

    # Check if version_string already exists
    my $found = $self->dbh->selectrow_array(
        "SELECT COUNT(*) FROM "
          . $self->schema_table()
          . " WHERE major_release=?",
        {}, $version_string
    );

    return 1 if ($found);

    $self->print($reason);
    $self->version($product);
    $self->major_release($version_string);
    $self->reason($reason);
    $self->start_time(time);

    return 0;
}

sub updated_new_style {
    my ($self) = @_;
    my $duration = time() - $self->start_time;
    $self->dbh->do(
        "INSERT INTO "
          . $self->schema_table()
          . " SET major_release=?, version=?, reason=?, created_at=FROM_UNIXTIME(?), duration=?",
        {},
        $self->major_release,
        $self->version,
        $self->reason,
        $self->start_time,
        $duration
    );
    $self->print( "Updated database to version " . $self->major_release . $/ );
}

sub updated_old_style {
    my ($self) = @_;
    $self->dbh->do(
        "UPDATE "
          . $self->schema_table()
          . " SET VERSION=? WHERE major_release=?",
        {}, $self->version, $self->major_release
    );
    $self->print( "Updated database to version "
          . $self->major_release . "."
          . $self->version
          . $/ );
    if ( defined( $self->stop_point ) && $self->version eq $self->stop_point ) {
        $self->print( "Stopping at this version", $/ );
        exit;
    }
}

=item $db->changed

Returns if this database has been changed with any schema updates

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
