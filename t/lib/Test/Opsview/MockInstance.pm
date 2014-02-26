
package Test::Opsview::MockInstance;

use strict;
use warnings;

use Test::Mock::Guard qw(mock_guard);
use Carp qw(croak);

sub new {
    my ( $class, $class_name, @methods ) = @_;

    my $c = 1;
    my @method_names = grep { $c++ % 2 } @methods;

    bless {
        guard        => mock_guard( $class_name, {@methods} ),
        class        => $class_name,
        method_names => \@method_names,
    }, $class;
}

sub call_count {
    my ( $self, $method_name ) = @_;

    if ($method_name) {
        return $self->{guard}->call_count( $self->{class}, $method_name );
    }
    elsif ( @{ $self->{method_names} } == 1 ) {
        return $self->{guard}
          ->call_count( $self->{class}, $self->{method_names}->[0] );
    }
    croak "method name not provided";
}

1;
