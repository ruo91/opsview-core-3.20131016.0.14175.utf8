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

package Opsview::Plugin;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 1674 $';

__PACKAGE__->table( "plugins" );

__PACKAGE__->columns( Primary => qw/name/, );
__PACKAGE__->columns( Others  => qw/help onserver/, );

__PACKAGE__->has_many(
    servicechecks => "Opsview::Servicecheck",
    { cascade => 'Fail' }
);
__PACKAGE__->has_many(
    agents => [ "Opsview::AgentPlugin" => "agentid" ],
    "pluginname"
);

__PACKAGE__->default_search_attributes( { order_by => "name" } );

=head1 NAME

Opsview::Plugin - Accessing plugin table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview plugin information

=head1 METHODS

=over 4

=item $class->retrieve_all_with_agents 

Retrieves an arrayref of a hashref of form:

[ { plugin => "plugin name", agents => { $agentid => 1, $agentid => 1 } } ]

=cut

__PACKAGE__->set_sql( retrieve_all_with_agents => <<"" );
SELECT __ESSENTIAL(me)__, ap.agentid as agentid
FROM __TABLE__ me
LEFT JOIN agentplugins ap
ON me.name = ap.pluginname
ORDER BY me.name


sub retrieve_all_with_agents {
    my $class       = shift;
    my $result      = [];
    my $p           = {};
    my $last_plugin = "";
    my $sth         = $class->sql_retrieve_all_with_agents;
    $sth->execute;
    while ( my $row = $sth->fetchrow_hashref ) {
        if ( $row->{name} ne $last_plugin ) {
            if ($last_plugin) {
                push @$result, $p;
                $p = {};
            }
            $last_plugin = $row->{name};
        }
        $p->{plugin} = $row->{name} unless $p->{plugin};
        $p->{agents}->{ $row->{agentid} } = 1 if $row->{agentid};
    }
    push @$result, $p;
    return $result;
}

=item $class->search_by_agent( $agentid )

Returns a list Opsview::Plugin objects which are allowed for the specified agentid

=cut

sub search_by_agent {
    my ( $class, $agentid ) = @_;
    if ($agentid) {
        return $class->search_by_agentid($agentid);
    }
    else {
        return $class->search( { onserver => 1 } );
    }
}

__PACKAGE__->set_sql( by_agentid => <<"" );
SELECT __ESSENTIAL(me)__
FROM __TABLE__ me, agentplugins ap
WHERE me.name = ap.pluginname
AND ap.agentid = ?


=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
