package Opsview::Statistics;

use strict;
use warnings;
use Mouse;
use namespace::autoclean;

has schema => (
    is  => 'rw',
    isa => 'DBIx::Class::Schema'
);

sub host_count { shift->schema->resultset('Hosts')->search->count }

__PACKAGE__->meta->make_immutable;
1;
