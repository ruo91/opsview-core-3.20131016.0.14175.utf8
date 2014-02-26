
package Opsview::DaemonClient;

use strict;
use warnings;

use IO::Socket::UNIX;

sub SERVER_SOCKET() {'/usr/local/nagios/var/rw/opsviewd.cmd'}

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;
    return $self;
}

sub check_daemon {
    if ( !-e SERVER_SOCKET() ) {
        die "opsviewd not running\n";
    }
    return 1;
}

my %CMDS_WITH_RESPONSE = (
    "promote_mib"     => 1,
    "web_reload_sync" => 1,
);

sub send {
    my ( $proto, $cmd, @msg ) = @_;

    my $sock = IO::Socket::UNIX->new(
        Peer    => SERVER_SOCKET(),
        Type    => SOCK_STREAM,
        Timeout => 10,
    ) or die "opsviewd not running: $!\n";

    $sock->print( "$cmd @msg\n" );

    if ( exists $CMDS_WITH_RESPONSE{$cmd} ) {
        while ( my $line = $sock->getline ) {
            print $line;
        }
    }
    $sock->close();
}

1;
