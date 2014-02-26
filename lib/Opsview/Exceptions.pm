package Opsview::Exceptions;

use strict;
use warnings;
use base 'Exporter';

use Exception::Class (
    'Opsview::Exceptions',

    'Opsview::Exceptions::Data::Malformed' => {
        isa         => 'Opsview::Exceptions',
        alias       => 'throw_data_malformed',
        description => 'malformed or unexpected data',
    },

    'Opsview::Exceptions::HTTP' => {
        isa         => 'Opsview::Exceptions',
        alias       => 'throw_http',
        description => 'HTTP transport layer',
        fields      => 'code',
    },

    'Opsview::Exceptions::Parameter' => {
        isa         => 'Opsview::Exceptions',
        alias       => 'throw_param',
        description => 'parameter',
    },

    'Opsview::Exceptions::System' => {
        isa         => 'Opsview::Exceptions',
        alias       => 'throw_system',
        description => 'system level',
    },

);

@Opsview::Exceptions::EXPORT_OK =
  qw( throw_data_malformed throw_http throw_param throw_system );

1;
