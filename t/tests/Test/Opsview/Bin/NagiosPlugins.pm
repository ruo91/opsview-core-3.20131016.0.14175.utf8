
package Test::Opsview::Bin::NagiosPlugins;

use strict;
use warnings;

use base qw( Test::Opsview );

use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;
use Test::File;
use File::Temp qw( tempfile );
use File::Slurp;
use File::Path 'remove_tree';

sub _setup_testing : Test(setup => no_plan) {
    my $self = shift;

    # restore default test DB
    $self->setup_db( qw( opsview ) );

    $self->{old_DBIC_UTF8COLUMNS_OK} = $ENV{DBIC_UTF8COLUMNS_OK};
    $ENV{DBIC_UTF8COLUMNS_OK} = 1;

}

sub _teardown_testing : Test(teardown) {
    my $self = shift;

    # restore previous value
    $ENV{DBIC_UTF8COLUMNS_OK} = delete $self->{old_DBIC_UTF8COLUMNS_OK};
}

1;
