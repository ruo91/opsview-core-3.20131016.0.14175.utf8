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

package Opsview::Keyword;
use base 'Opsview';

use strict;

__PACKAGE__->table( "keywords" );
__PACKAGE__->utf8_columns(qw/description/);
__PACKAGE__->columns( Primary => qw/id/ );
__PACKAGE__->columns(
    Essential => qw/name description enabled style exclude_handled/ );

__PACKAGE__->columns( Stringify => qw/name/ );

__PACKAGE__->has_many(
    hosts => [ "Opsview::KeywordHost" => 'hostid' ],
    "keywordid"
);
__PACKAGE__->has_many(
    hostgroups => [ "Opsview::KeywordHostgroup" => 'hostgroupid' ],
    "keywordid"
);
__PACKAGE__->has_many(
    hosttemplates => [ "Opsview::KeywordHosttemplate" => 'hosttemplateid' ],
    "keywordid"
);
__PACKAGE__->has_many(
    servicechecks => [ "Opsview::KeywordServicecheck" => 'servicecheckid' ],
    "keywordid"
);
__PACKAGE__->has_many(
    servicegroups => [ "Opsview::KeywordServicegroup" => 'servicegroupid' ],
    "keywordid"
);

__PACKAGE__->default_search_attributes( { order_by => "name" } );

__PACKAGE__->mk_classdata( "styles" );
__PACKAGE__->styles(
    {
        labels => {
            group_by_host    => "Group by host",
            group_by_service => "Group by service"
        },
        values => [qw/group_by_host group_by_service/],
    }
);

sub count_all_services {
    return Runtime::Searches->count_services_by_keyword(shift);
}

=item my_type_is

Returns "keyword"

=cut

sub my_type_is {
    return "keyword";
}

1;
