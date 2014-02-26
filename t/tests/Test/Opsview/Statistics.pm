
package Test::Opsview::Statistics;

use strict;
use warnings;

use base qw( Test::Opsview );

use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;

sub _setup_testing : Test(setup => no_plan) {
    my $self = shift;

    # restore default test DB
    $self->setup_db( qw( opsview ) );

    use_ok 'Opsview::Schema' or die "Cannot load Opsview::Schema";

    $self->{schema} = Opsview::Schema->my_connect;
    isa_ok( $self->{schema}, 'Opsview::Schema' );
    isa_ok( $self->{schema}, 'DBIx::Class::Schema' );

    use_ok 'Opsview::Statistics' or die "Cannot load Opsview::Statistics";

    $self->{stats} =
      new_ok( 'Opsview::Statistics' => [ schema => $self->{schema} ] );
}

sub host_count : Test(2) {
    my $self = shift;

    can_ok( 'Opsview::Statistics', 'host_count' );
    is( $self->{stats}->host_count, 24, 'Correct number of hosts' );
}

1;
