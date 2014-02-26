#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#
package Runtime::Schema::OpsviewHostsMatpaths;

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 NAME

Runtime::Schema::OpsviewHostsMatpaths

=cut

__PACKAGE__->table( "opsview_hosts_matpaths" );

__PACKAGE__->add_columns(
    "id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "object_id",
    {
        data_type   => "integer",
        is_nullable => 0
    },
    "matpath",
    {
        data_type   => "text",
        is_nullable => 0,
        size        => 64
    },
);
__PACKAGE__->set_primary_key( "id" );

__PACKAGE__->belongs_to(
    "host",
    "Runtime::Schema::OpsviewHosts",
    { "foreign.id" => "self.object_id" },
);

1;
