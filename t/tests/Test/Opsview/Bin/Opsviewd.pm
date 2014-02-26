
package Test::Opsview::Bin::Opsviewd;

use strict;
use warnings;

use base qw( Test::Opsview );

use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;
use Test::File;
use File::Temp qw( tempfile );
use File::Slurp;
use Proc::ProcessTable;

sub _setup_testing : Test(setup => no_plan) {
    my $self = shift;

    # restore default test DB
    $self->setup_db( qw( opsview ) );

    $self->{cmd} = "bin/opsviewd";

    file_exists_ok( $self->{cmd} );
    file_executable_ok( $self->{cmd} );

}

sub _teardown_testing : Test(teardown) {
    my $self = shift;

    # teardown testing placeholder
}

sub start_opsviewd {
    my $self = shift;

    $self->{opsviewd_log}            = '/var/log/opsview/opsviewd.log';
    $self->{opsviewd_log_line_count} = qx( wc -l $self->{opsviewd_log} );
    chomp $self->{opsviewd_log_line_count};
    $self->{opsviewd_log_line_count} =~ s/^(\d+).*/$1/;
    is( system( $self->{cmd} ), 0, "opsviewd started" )
      or die "opsviewd not started";

    sleep 2;
    $self->{proc_table} = Proc::ProcessTable->new();

    my $opsview_pid = read_file( '/usr/local/nagios/var/opsview.pid' );
    chomp $opsview_pid;

    for my $p ( @{ $self->{proc_table}->table } ) {
        if ( $p->pid == $opsview_pid && $p->fname eq 'opsviewd' ) {
            $self->{opsviewd_process} = $p;
            sleep 5;
            last;
        }
    }
    unless ( $self->{opsviewd_process} ) {
        kill( 9, $opsview_pid );
        system( "killall opsviewd" );
        die "opsviewd not found in process table";
    }
}

sub stop_opsviewd {
    my $self = shift;
    $self->{opsviewd_process}->kill(15);
    delete $self->{opsviewd_process};
    sleep 5;
}

1;
