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

package Runtime;
use strict;
use lib "/usr/local/nagios/perl/lib";
use Class::DBI::Sweet;
use base "Exporter", 'Class::DBI::Sweet', "Opsview::Base", "ClassDBIExtras";
use Opsview::Config;
use Class::DBI::utf8 qw(-nosearch);

use Carp;
use Exporter;
our $VERSION   = '$Version$';
our @EXPORT_OK = qw(&lookup_name);

my $db_options = {
    RaiseError           => 1,
    AutoCommit           => 1,
    mysql_auto_reconnect => 1
};

__PACKAGE__->connection(
    Opsview::Config->runtime_dbi
      . ":database="
      . Opsview::Config->runtime_db
      . ";host=localhost",
    Opsview::Config->runtime_dbuser,
    Opsview::Config->runtime_dbpasswd,
    $db_options,
    { on_connect_do => "SET time_zone='+00:00'" }
);

# Cacheable and reusable connection to Opsview database
# Only connects and loads libraries as required
my $opsview_schema;

sub opsview_schema {
    require Opsview::Schema;
    return $opsview_schema if $opsview_schema;
    $opsview_schema = Opsview::Schema->my_connect;
}

=head1 NAME

Runtime - Middleware for runtime database

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Runtime data storage

=head1 METHODS

=over 4

sub db { Opsview::Config->runtime_db }

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
