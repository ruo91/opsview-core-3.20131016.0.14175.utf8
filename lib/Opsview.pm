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

package Opsview;
use strict;
use lib "/usr/local/nagios/perl/lib";

use Carp;
use Exporter;
use ClassDBIExtras;
use Class::Data::Inheritable;
use Module::Pluggable require => 1;
our $VERSION   = '$Version$';
our @EXPORT_OK = qw(&lookup_name);
use Class::DBI::utf8 qw(-nosearch);

use Opsview::Config;
use base "Exporter", "ClassDBIExtras", "Class::Data::Inheritable",
  "Opsview::Base";

my $db_options = {
    RaiseError           => 1,
    AutoCommit           => 1,
    ChopBlanks           => 0,
    mysql_auto_reconnect => 1
};

__PACKAGE__->connection(
    Opsview::Config->dbi
      . ":database="
      . Opsview::Config->db
      . ";host=localhost",
    Opsview::Config->dbuser,
    Opsview::Config->dbpasswd,
    $db_options,
    { on_connect_do => "SET time_zone='+00:00'" },
);

sub my_connection_params {
    my ( $class, $db ) = @_;
    if ( $db eq "runtime" ) {
        return (
            Opsview::Config->runtime_dbi
              . ":database="
              . Opsview::Config->runtime_db
              . ";host=localhost",
            Opsview::Config->runtime_dbuser,
            Opsview::Config->runtime_dbpasswd, $db_options
        );
    }
    else {
        croak "Unknown db: $db";
    }
}

=head1 NAME

Opsview - Middleware for opsview databases

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview configuration information

=head1 METHODS

=over 4

=item get_logger( $facility )

Initialises a Log::Log4perl object and return object from a Log::Log4perl->get_logger call. 
Use in CLI tools - opsview-web uses Catalyst's Log4perl

=cut

sub get_logger {
    my $facility = shift or die "Must specify a facility";
    require Log::Log4perl;
    Log::Log4perl::init( Opsview::Config->root_dir . "/etc/Log4perl.conf" );
    return Log::Log4perl->get_logger($facility);
}

=item lookup_name($array_ref)

Returns a list of names for the array ref key. 
This is required because the use of stringify causes deletes to fail

=cut

sub lookup_name {
    my $array_ref = shift;
    if ( ref $array_ref ne "ARRAY" ) {
        croak "Wrong call to lookup_name - must be array_ref";
    }
    my @a;
    foreach $_ (@$array_ref) {
        push @a, $_->name;
    }
    return @a;
}

=item initial_columns

Returns an array ref of the initial columns for this class. These columns should be 
set when calling create from your program. Values must be set for these columns at 
create time - usually for the columns that cannot be NULL when creating a new row

In the class, use:
   __PACKAGE__->initial_columns(qw/name category/);

=cut

# This uses Class::DBI's mk_classdata to implement, so that the data is stored
# in the class, for all instances
sub initial_columns {
    my ( $class, @list ) = @_;
    return $class->mk_classdata( 'initial_columns', \@list );
}

=item Opsview->convert_type_to_class

Given a type, will return the corresponding Opsview::* class

=cut

sub convert_type_to_class {
    my $class = shift;
    ( $_ = shift ) =~ s/(\w+\S*\w*)/\u\L$1/g; # Uppercase first letter
    return "Opsview::$_";
}

=item authentication

Returns the authentication mechanism used. Current values: "htpasswd"

=cut

sub authentication {
    my $auth = Opsview::Config->authentication || "htpasswd";
    die "Unknown authentication method: $auth" unless $auth =~ /^htpasswd$/;
    return $auth;
}

=item Opsview->admin_classes

Returns an array ref containing a list of the classes that are directly altered 
from the CGIs

=cut

my @admin_classes = qw(Monitoringserver);
sub admin_classes { return \@admin_classes }

=item Opsview->all_committed

Returns true if all rows are committed, else returns false (ie, a config reload
is required)

=cut

sub all_committed {
    foreach my $class ( @{ Opsview->admin_classes } ) {
        my $oclass = "Opsview::$class";
        return 0 if ( $oclass->count( uncommitted => 1 ) );
    }
    return 1;
}

=item Opsview->invalid_nagios_chars

Returns a scalar containing all the characters that Nagios will not accept in names

=cut

sub invalid_nagios_chars {q{`~!$%^&*|'"<>?,()=}}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
