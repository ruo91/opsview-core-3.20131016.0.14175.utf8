use strict;
use warnings;

use Test::More tests => 8;

#use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$Bin/../lib", "t/lib", "$Bin/../etc";

BEGIN {
    use_ok( "Opsview::Sshcommands" );
}

{

    package ConnectionsBase;
    use warnings;
    use strict;
    use Class::Struct;
    struct "ConnectionsBase" => {
        name       => '$',
        active     => '$',
        ip         => '$',
        slave_port => '$',
    };

    1;
}

{

    package Connections;
    use warnings;
    use strict;
    use FindBin qw($Bin);
    use lib "$Bin/../lib", "t/lib", "$Bin/../etc";
    use Opsview::Sshcommands;
    use base qw(ConnectionsBase Opsview::Sshcommands);

    1;
}

use Test::MockObject;
my $slave_initiated = 0;
my $mock            = Test::MockObject->new();
$mock->fake_module( 'Opsview::Config',
    'slave_initiated' => sub {$slave_initiated}, );

my $expected;
my $command;

use_ok( "Opsview::Sshcommands" );

my $obj = Connections->new(
    name        => "server1",
    active      => 1,
    ip          => "127.0.0.1",
    slave_port  => 22,
    remote_addr => "128.1.1.1",
);

$expected = "ssh -o ConnectTimeout=10 -o BatchMode=yes 127.0.0.1 hostname";
$command  = $obj->ssh_command( "hostname" );
is_deeply( $command, $expected, "testing master initiated tunnel ssh commands"
);

$expected =
  "scp -o ConnectTimeout=10 -o BatchMode=yes /tmp/testfile 127.0.0.1:/tmp/testfile1";
$command = $obj->scp_file_out( "/tmp/testfile", "/tmp/testfile1" );
is_deeply( $command, $expected, "testing master initiated tunnel scp commands"
);

$slave_initiated = 1;
$expected =
  "ssh -o ConnectTimeout=10 -o BatchMode=yes -o HostKeyAlias=server1-ssh -p 22 127.0.0.1 hostname";
$command = $obj->ssh_command( "hostname" );
is_deeply( $command, $expected, "testing slave initiated tunnel ssh commands"
);

$expected =
  "scp -o ConnectTimeout=10 -o BatchMode=yes -o HostKeyAlias=server1-ssh -P 22 /tmp/testfile 127.0.0.1:/tmp/testfile1";
$command = $obj->scp_file_out( "/tmp/testfile", "/tmp/testfile1" );
is_deeply( $command, $expected, "testing slave initiated tunnel scp commands"
);

# Other ssh_command tests
my @command = ( "echo", '\$SHELL' );
my @expected = (
    "ssh", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes", "-o",
    "HostKeyAlias=server1-ssh", "-p", "22", "127.0.0.1", "'echo'",
    '\'\$SHELL\''
);
my @got = $obj->ssh_command( \@command );
is_deeply( \@got, \@expected, "Checking shell escapes correctly" );

@command =
  ( "echo", "It's a long way to Tipperary - I have to spend my \$\$s there!" );
@expected = (
    "ssh", "-o", "ConnectTimeout=10", "-o", "BatchMode=yes", "-o",
    "HostKeyAlias=server1-ssh", "-p", "22", "127.0.0.1", "'echo'",
    '\'It\'"\'"\'s a long way to Tipperary - I have to spend my $$s there!\''
);
@got = $obj->ssh_command( \@command );
is_deeply( \@got, \@expected, "Funny shell stuff here" );
