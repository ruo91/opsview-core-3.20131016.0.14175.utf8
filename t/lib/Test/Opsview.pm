package Test::Opsview;

use strict;
use warnings;

use FindBin '$Bin';

use base qw( Test::Class );
use Test::More;
use Test::WWW::Mechanize::Catalyst;
use File::Path 'remove_tree';
use File::Spec;
use Test::Opsview::MockInstance;

# Fail if method returned before running all the tests
sub fail_if_returned_early {1}

our %WEB_AUTH = (
    user => 'admin',
    pass => 'initial',
);

BEGIN { $ENV{AUTOMATED_TESTS} = 1; }

sub setup_db {
    my ( $self, @args ) = @_;

    # Runtime db restore requires a stop of opsview
    if ( grep { $_ =~ /^runtime\.?/ } @args ) {

        # Stop opsview first, because db shouldn't be updated during this process
        is( system("/usr/local/nagios/bin/rc.opsview stop"),
            0, "Opsview stopped" )
          or die "Cannot stop opsview";
    }

    # Handle when $db is db.filename format.
    for my $arg (@args) {
        next unless $arg =~ /^([^.]+)\.(.*)$/;
        my ( $db, $filename ) = ( $1, $2 );
        is(
            system(
                "/usr/local/nagios/bin/db_$db -t db_restore < $Bin/../../opsview-core/t/var/$db.$filename"
            ),
            0,
            "Restored $filename"
        ) or die "Cannot restore $filename";
    }

    # Restore other databases. These are outside of the above for loop because
    # they need to happen last, maybe.
    # Need to go up two levels because opsview-web also calls this.
    if ( grep { $_ eq 'opsview' } @args ) {
        is(
            system(
                "/usr/local/nagios/bin/db_opsview -t db_restore < $Bin/../../opsview-core/t/var/opsview.test.db"
            ),
            0,
            "Restored opsview"
        ) or die "Cannot restore opsview";
    }

    if ( grep { $_ eq 'runtime_install' } @args ) {
        is( system("/usr/local/nagios/bin/db_runtime -t db_install"),
            0, "Restored initial runtime" )
          or die "Cannot restore initial runtime";
    }

    if ( grep { $_ eq 'runtime' } @args ) {
        is(
            system(
                "/usr/local/nagios/bin/db_runtime -t db_restore < $Bin/../../opsview-core/t/var/runtime.test.db"
            ),
            0,
            "Restored runtime"
        ) or die "Cannot restore runtime";
    }

    if ( grep { $_ eq 'rrds' } @args ) {
        my $rrddir = "/usr/local/nagios/var/rrd";
        is( system("rm -fr $rrddir/*"), 0, "Deleted contents of $rrddir" )
          or die "Cannot delete contents of $rrddir: $!";
        is(
            system(
                "cd $rrddir && tar --gzip -xf '$Bin/../../opsview-core/t/var/rrd/dumpedrrds.tar.gz'"
            ),
            0,
            "Restored rrds"
        ) or die "Cannot restore rrds";
        require RRDs;
        require File::Next;
        my $files = File::Next::files( "$rrddir" );
        while ( defined( my $file = $files->() ) ) {
            next unless $file =~ /\.dump$/;
            my $rrd = $file;
            $rrd =~ s/\.dump$//;
            RRDs::restore( $file, $rrd, "-f" );
        }
    }
}

# to make sure it runs only once (unlike shutdown which will run for each test class)
sub _final_shutdown_testing {
    my $self = shift;
}

sub mech { $_[0]->{mech} }

sub mech_web_login {
    my ( $self, $user, $pass, $mech ) = @_;

    $user ||= $WEB_AUTH{user};
    $pass ||= $WEB_AUTH{pass};
    $mech ||= $self->{mech};

    subtest 'Web login' => sub {
        plan tests => 2;
        $mech->get_ok( '/' );
        $mech->submit_form(
            with_fields => {
                login_username => $user,
                login_password => $pass,
                noscript       => 0
            }
        );
        ok(
            $mech->find_link(
                text  => $user,
                url   => '/user/preference',
                class => 'opsview_drop'
            ),
            "Logged in as $user"
        );
    };
}

sub setup_mechanized_web {
    my ( $self, %args ) = @_;

    $self->{mech} =
      Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'Opsview::Web' );

    if ( $args{login} ) {
        $self->mech_web_login();
    }
}

sub mech_rest { $_[0]->{mech_rest} }

sub mech_rest_api_login {
    my ( $self, $user, $pass ) = @_;

    $user ||= $WEB_AUTH{user};
    $pass ||= $WEB_AUTH{pass};

    subtest 'REST login' => sub {
        plan tests => 2;

        $self->{mech_rest}->delete_header( 'Content-Type', 'X-Opsview-Username',
            'X-Opsview-Token', );

        $self->{mech_rest}->post_ok(
            '/rest/login',
            {
                username => $user,
                password => $pass
            }
        );

        my $json = JSON->new->decode( $self->{mech_rest}->content );
        ok( $json->{token}, "Logged in as $user" );

        $self->{mech_rest}->add_header( 'Content-Type' => 'application/json' );
        $self->{mech_rest}->add_header( 'X-Opsview-Username' => $user );
        $self->{mech_rest}->add_header( 'X-Opsview-Token' => $json->{token} );

    };
}

sub setup_mechanized_rest {
    my ( $self, %args ) = @_;

    $self->{mech_rest} =
      Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'Opsview::Web' );

    if ( $args{login} ) {
        $self->mech_rest_api_login();
    }
}

sub mock {
    my $self = shift;

    return Test::Opsview::MockInstance->new(@_);
}

=head2 find_processes

    my @procs = $self->find_processes(
        {
            fname => 'opsviewd',
        }
    );

Find all running processes filtered by the search criteria (keys should match
methods provided by Proc::ProcessTable::Process)

Values are compared using eq.

=cut

sub find_processes {
    my ( $self, $filter ) = @_;

    my $proc_table = Proc::ProcessTable->new();

    my @processes;

    my @criteria = keys %{ $filter || {} };
    my $req_matches = scalar @criteria;

    for my $p ( @{ $proc_table->table } ) {
        my $not_matched = $req_matches;
        for my $m (@criteria) {
            --$not_matched if $p->$m() eq $filter->{$m};
        }
        unless ($not_matched) {
            note "Found matching process: pid/"
              . $p->pid
              . ", fname/"
              . $p->fname;
            push @processes, $p;
        }
    }

    return @processes;
}

sub stop_processes {
    my ( $self, $filter, $signal ) = @_;

    $signal = 15 unless defined $signal;

    subtest 'Stopping processes' => sub {
        my @processes = $self->find_processes($filter);

        SKIP: {
            skip "No matching processes were found", 1
              unless @processes;

            my $killed = 0;
            for my $proc (@processes) {
                $killed += $proc->kill($signal);
            }

            is(
                $killed,
                scalar @processes,
                "Killed $killed all found processes"
            );
        }
      }
}

1;
