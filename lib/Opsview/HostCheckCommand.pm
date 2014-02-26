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

package Opsview::HostCheckCommand;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 2801 $';

__PACKAGE__->table( "hostcheckcommands" );

__PACKAGE__->columns( Essential => qw/id name plugin args priority/, );

__PACKAGE__->initial_columns(qw/name plugin args/);

__PACKAGE__->columns( Stringify => qw/name/ );

__PACKAGE__->has_a( plugin => "Opsview::Plugin" );

__PACKAGE__->has_many(
    hosts => "Opsview::Host",
    { cascade => 'Fail' }
);

__PACKAGE__->default_search_attributes( { order_by => "priority" } );

=head1 NAME

Opsview::HostCheckCommand - Accessing hostcheckcommands table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview hostcheckcommands information

=head1 METHODS

=over 4

=item number_of_hosts

Returns the number of hosts that use this host check command. Required because of inconsistent
results coming from TT when calling object.hosts.count

=cut

sub number_of_hosts {
    my $self = shift;
    my $it   = $self->hosts;
    return $it->count;
}

=item my_type_is

Returns "host check command"

=cut

sub my_type_is {
    return "host check command";
}

=back 

=head1 AUTHOR

  - Capside, J L Martinez
  - Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
