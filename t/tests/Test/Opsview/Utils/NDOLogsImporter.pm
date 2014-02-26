package Test::Opsview::Utils::NDOLogsImporter;

use strict;
use warnings;

use base qw( Test::Opsview );

use FindBin '$Bin';
use lib "$Bin/../lib";
use Test::More;

{

    package Test::Opsview::Utils::NDOLogsImporter::Logger;

    our %LOG;

    no warnings 'closure';
    sub new { bless {}, shift }
    for my $method (qw( debug info warn fatal logdie )) {
        eval qq|
            sub Test::Opsview::Utils::NDOLogsImporter::Logger::$method {
                my \$self = shift;
                push \@{ \$LOG{$method} }, "\@_";
                Test::More::diag "[\U$method\E] \@_";
            }
            sub Test::Opsview::Utils::NDOLogsImporter::Logger::is_$method {
                return 1;
            }
        |;
    }
}

sub _setup_testing : Test(setup => no_plan) {
    my $self = shift;

    # restore default test DB
    $self->setup_db( qw( runtime_install ) );

    use_ok 'Opsview::Utils::NDOLogsImporter'
      or die "Cannot load Opsview::Utils::NDOLogsImporter";

    $self->{file} = "t/var/ndologs/1353330306.904093";

    my $break = 0;

    $self->{importer} = new_ok(
        'Opsview::Utils::NDOLogsImporter' => [
            logger => Test::Opsview::Utils::NDOLogsImporter::Logger->new(),
            break  => \$break,
        ]
    );
    is(
        scalar keys %{ $self->{importer}->{objects_cache} },
        0, "nagios objects are cached"
    );

    # diag explain $self->{importer};
}

sub _verify_chunks {
    my ( $expected, $chunks ) = @_;

    my @counts = @{ $expected->{chunks} };

    for ( my $i = 0; $i < scalar @$chunks; $i++ ) {
        my $size = scalar @{ $counts[$i] } / 2;
        is(
            scalar @{ $chunks->[$i] } / 2,
            $size, "Chunk $i has correct size $size"
        );
        for ( my $j = 0; $j < 2 * $size; $j += 2 ) {

            #diag "$i/$j";
            my $type  = $counts[$i]->[$j];
            my $count = $counts[$i]->[ $j + 1 ];
            is( $chunks->[$i]->[$j], $type, "...and has event $type" );
            is(
                scalar @{ $chunks->[$i]->[ $j + 1 ] },
                $count, "......with correct number of entries: $count"
            );
        }
    }

    my $first = $expected->{first};
    my $last  = $expected->{last};
    is( $chunks->[0]->[0], $first->{event}, "Correct first event type" );

    #$DB::single=1;
    is_deeply(
        $chunks->[0]->[1]->[0]->[ $first->{field} ],
        $first->{value}, "...and data read correctly"
    );

    is( $chunks->[-1]->[-2], $last->{event}, "Correct last event type" );
    is_deeply(
        $chunks->[-1]->[-1]->[-1]->[ $last->{field} ],
        $last->{value}, "...and data read correctly"
    );
}

sub parse : Test(7) {
    my $self = shift;

    my $PREV_MAX_BUF = $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE;

    subtest "File ok" => sub {
        plan tests => 277;

        $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE = 800;

        my @chunks = ();
        while (
            my $chunk = Opsview::Utils::NDOLogsImporter::parse_in_chunks(
                $self->{file}, -s $self->{file}
            )
          )
        {
            push @chunks, $chunk;
        }

        #diag explain \@chunks;

        my %expected = (
            chunks => [
                [ # 0
                    206 => 1,
                ],
                [ # 1
                    213 => 1,
                    206 => 1,
                ],
                [ # 2
                    213 => 1,
                    206 => 1,
                ],
                [ # 3
                    213 => 1,
                    205 => 1,
                ],
                [ # 4
                    220 => 1,
                    221 => 1,
                    220 => 1,
                ],
                [ # 5
                    205 => 1,
                    213 => 1,
                ],
                [ # 6
                    223 => 1,
                    211 => 1,
                    206 => 1,
                ],
                [ # 7
                    213 => 1,
                ],
                [ # 8
                    206 => 1,
                    213 => 1,
                ],
                [ # 9
                    206 => 1,
                    213 => 1,
                ],
                [ # 10
                    206 => 1,
                    213 => 1,
                ],
                [ # 11
                    206 => 1,
                ],
                [ # 12
                    213 => 1,
                ],
                [ # 13
                    206 => 1,
                ],
                [ # 14
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 15
                    206 => 1,
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 16
                    206 => 1,
                    213 => 1,
                    206 => 1,
                    213 => 1,
                    206 => 1,
                ],
                [ # 17
                    213 => 1,
                    206 => 1,
                    213 => 1,
                    206 => 1,
                ],
                [ # 18
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 19
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 20
                    213 => 1,
                    206 => 1,
                ],
                [ # 21
                    213 => 2,
                ],
                [ # 22
                    206 => 1,
                    213 => 2,
                ],
                [ # 23
                    206 => 1,
                    213 => 1,
                ],
                [ # 24
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 25
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 26
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 27
                    213 => 1,
                    206 => 1,
                ],
                [ # 28
                    213 => 2,
                    206 => 1,
                ],
                [ # 29
                    213 => 2,
                    206 => 1,
                ],
                [ # 30
                    213 => 2,
                    206 => 1,
                ],
                [ # 31
                    213 => 2,
                ],
                [ # 32
                    206 => 1,
                    213 => 1,
                ],
                [ # 33
                    213 => 1,
                    206 => 1,
                    213 => 1,
                    211 => 1,
                ],
                [ # 34
                    206 => 1,
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 35
                    206 => 1,
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 36
                    206 => 1,
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 37
                    206 => 1,
                    213 => 1,
                ],
                [ # 38
                    206 => 1,
                ],
                [ # 39
                    213 => 1,
                    206 => 1,
                    213 => 1,
                ],
                [ # 40
                    206 => 1,
                    213 => 1,
                    206 => 1,
                ],
                [ # 41
                    213 => 1,
                ],
                [ # 42
                    206 => 1,
                ],
                [ # 43
                    213 => 1,
                    206 => 1,
                    213 => 1,
                    206 => 1,
                ],
                [ # 44
                    213 => 1,
                    206 => 1,
                    213 => 1,
                    206 => 1,
                    213 => 2,
                    206 => 1,
                ],
                [ # 45
                    411 => 1,
                    213 => 2,
                ],
            ],
            first => {
                event => '206',
                field => '95',
                value => "No route to host",
            },
            last => {
                event => '213',
                field => '11',
                value =>
                  'check_tcp!-H $HOSTADDRESS$ -p 9999 -E -s "STATUS_PCS\\\\r" -E -e PCS_UP',
            }
        );

        _verify_chunks( \%expected, \@chunks );

        is(
            $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE,
            3200, "MAX_BUF_SIZE was increased to 3200"
        );
    };

    subtest "File corrupted - sequence of events" => sub {
        plan tests => 11;

        $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE = 800;

        my $file = "t/var/ndologs/1353330306.904093.corrupted.seq";
        note $file;

        my @chunks = ();
        while ( my $chunk =
            Opsview::Utils::NDOLogsImporter::parse_in_chunks( $file, -s $file )
          )
        {
            push @chunks, $chunk;
        }

        #diag explain \@chunks;

        my %expected = (
            chunks => [ [ 206 => 1, ], [ 213 => 1, ] ],
            first => {
                event => '206',
                field => '4',
                value => "1353330301.663487",
            },
            last => {
                event => '213',
                field => '4',
                value => '1353330301.663575',
            }
        );

        _verify_chunks( \%expected, \@chunks );

        is(
            $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE,
            800, "MAX_BUF_SIZE was kept at 800"
        );
    };

    subtest "File corrupted - single event" => sub {
        plan tests => 11;

        $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE = 800;

        my $file = "t/var/ndologs/1353330306.904093.corrupted.single";
        note $file;

        my @chunks = ();
        while ( my $chunk =
            Opsview::Utils::NDOLogsImporter::parse_in_chunks( $file, -s $file )
          )
        {
            push @chunks, $chunk;
        }

        #diag explain \@chunks;

        my %expected = (
            chunks => [ [ 206 => 1, ], [ 213 => 1, ] ],
            first => {
                event => '206',
                field => '4',
                value => "1353330301.663487",
            },
            last => {
                event => '213',
                field => '4',
                value => '1353330301.663575',
            }
        );

        _verify_chunks( \%expected, \@chunks );

        is(
            $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE,
            800, "MAX_BUF_SIZE was kept at 800"
        );
    };

    subtest "File corrupted - after ignored event" => sub {
        plan tests => 11;

        $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE = 800;

        my $file = "t/var/ndologs/1353330306.904093.corrupted.ignored.after";
        note $file;

        my @chunks = ();
        while ( my $chunk =
            Opsview::Utils::NDOLogsImporter::parse_in_chunks( $file, -s $file )
          )
        {
            push @chunks, $chunk;
        }

        #diag explain \@chunks;

        my %expected = (
            chunks => [ [ 206 => 1, ], [ 213 => 1, ] ],
            first => {
                event => '206',
                field => '4',
                value => "1353330301.663487",
            },
            last => {
                event => '213',
                field => '4',
                value => '1353330301.663575',
            }
        );

        _verify_chunks( \%expected, \@chunks );

        is(
            $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE,
            800, "MAX_BUF_SIZE was kept at 800"
        );
    };

    subtest "File corrupted - before ignored event" => sub {
        plan tests => 11;

        $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE = 800;

        my $file = "t/var/ndologs/1353330306.904093.corrupted.ignored.before";
        note $file;

        my @chunks = ();
        while ( my $chunk =
            Opsview::Utils::NDOLogsImporter::parse_in_chunks( $file, -s $file )
          )
        {
            push @chunks, $chunk;
        }

        #diag explain \@chunks;

        my %expected = (
            chunks => [ [ 206 => 1, ], [ 213 => 1, ] ],
            first => {
                event => '206',
                field => '4',
                value => "1353330301.663487",
            },
            last => {
                event => '213',
                field => '4',
                value => '1353330301.663575',
            }
        );

        _verify_chunks( \%expected, \@chunks );

        is(
            $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE,
            1600, "MAX_BUF_SIZE was increased to 1600"
        );
    };

    subtest "File corrupted - only ignored events" => sub {
        plan tests => 2;

        $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE = 800;

        my $file = "t/var/ndologs/1353330306.904093.corrupted.only.ignored";
        note $file;

        my @chunks = ();
        while ( my $chunk =
            Opsview::Utils::NDOLogsImporter::parse_in_chunks( $file, -s $file )
          )
        {
            push @chunks, $chunk;
        }

        #diag explain \@chunks;

        is( scalar @chunks, 0, "No events found in empty file" );

        is(
            $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE,
            800, "MAX_BUF_SIZE was kept at 800"
        );
    };

    subtest "File corrupted - no events" => sub {
        plan tests => 2;

        $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE = 800;

        my $file = "t/var/ndologs/1353330306.904093.corrupted.no.events";
        note $file;

        my @chunks = ();
        while ( my $chunk =
            Opsview::Utils::NDOLogsImporter::parse_in_chunks( $file, -s $file )
          )
        {
            push @chunks, $chunk;
        }

        #diag explain \@chunks;

        is( scalar @chunks, 0, "No events found in empty file" );

        is(
            $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE,
            800, "MAX_BUF_SIZE was kept at 800"
        );
    };

    $Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE = $PREV_MAX_BUF;
}

sub send_log : Test(54) {
    my $self = shift;

    my $_events = [
        900 => [
            {
                245 => 'RETAINED',
                4   => 1326199839.860038,
            },
        ],
        901 => [ { 4 => 1326199839.860038, }, ],
        206 => [
            {
                1   => 701,
                2   => 0,
                3   => 0,
                4   => 1353330301.663487,
                53  => 'ov-build-hardy-32',
                114 => 'SSH 1022',
                12  => 1,
                25  => 2,
                76  => 2,
                121 => 1,
                118 => 2,
                123 => 60,
                127 => 'set_to_stale',
                13  => '',
                14  => '',
                117 => 1353330299.0,
                33  => 1353330299.0,
                32  => 0,
                42  => 0.00000,
                71  => 0.38589,
                110 => 2,
                95  => 'No route to host',
                99  => '',
            }
        ],
        213 => [
            {
                1   => '1202',
                2   => '0',
                3   => '0',
                4   => '1353330301.663575',
                53  => 'ov-build-hardy-32',
                114 => 'SSH 1022',
                95  => 'No route to host',
                99  => '',
                27  => '2',
                51  => '1',
                115 => '0',
                25  => '2',
                76  => '2',
                61  => '1353330299',
                83  => '1352091947',
                12  => '1',
                63  => '1340638755',
                57  => '1340638755',
                56  => '2',
                66  => '1340638625',
                70  => '0',
                67  => '1339400625',
                64  => '1353330299',
                121 => '1',
                62  => '0',
                84  => '0',
                85  => '0',
                88  => '1',
                101 => '0',
                7   => '0',
                26  => '0',
                97  => '1',
                38  => '1',
                9   => '0',
                47  => '1',
                54  => '0',
                98  => '0.00000',
                71  => '0.38589',
                42  => '0.00000',
                113 => '0',
                45  => '1',
                103 => '1',
                93  => '0',
                80  => '0',
                37  => '',
                11  => 'set_to_stale',
                86  => '2.000000',
                109 => '1.000000',
                209 => '24x7',
            },
            {
                1   => "1202",
                2   => "0",
                3   => "0",
                4   => "1353330305.179876",
                53  => "test-unhandled",
                114 => "Unhandled Services by hostgroup: Production Systems",
                95 =>
                  "OPSVIEW_SERVICES OK - Total unhandled services 1 (critical=>0, warning=> 0, unknown=> 1 )",
                99  => "unhandled_services=1;5;10",
                27  => "0",
                51  => "1",
                115 => "1",
                25  => "1",
                76  => "3",
                61  => "1353330301",
                83  => "1353330601",
                12  => "0",
                63  => "1350317574",
                57  => "1350317574",
                56  => "0",
                66  => "1353330301",
                70  => "1335622335",
                67  => "0",
                64  => "1350317274",
                121 => "1",
                62  => "0",
                84  => "0",
                85  => "0",
                88  => "1",
                101 => "0",
                7   => "0",
                26  => "0",
                97  => "1",
                38  => "1",
                9   => "1",
                47  => "1",
                54  => "0",
                98  => "0.00000",
                71  => "0.78000",
                42  => "2.48909",
                113 => "0",
                45  => "1",
                103 => "1",
                93  => "0",
                80  => "0",
                37  => "",
                11 =>
                  "check_opsview_services!--hostgroup='Production Systems' -w 5 -c 10",
                86  => "5.000000",
                109 => "1.000000",
                209 => "24x7",
            }
        ],
        205 => [
            {
                1   => 600,
                2   => 0,
                3   => 0,
                4   => 1353330301.664502,
                89  => 1,
                117 => 1353330301.664306,
                33  => 0.0,
                53  => 'bob',
                114 => 'Unix disk: /srv/released',
                87  => 0,
                26  => 8771,
                118 => 1,
                95 =>
                  'DISK WARNING - free space: /srv/released 14253 MB (9% inode=99%):',
                5  => '',
                6  => '',
                36 => 0,
                24 => 0,
            },
        ],
        220 => [
            {
                1   => 602,
                2   => 0,
                3   => 0,
                4   => 1353330301.664645,
                89  => 1,
                117 => 1353330301.664644,
                33  => 0.0,
                53  => 'bob',
                114 => 'Unix disk: /srv/released',
                134 => 'admin/02test-snp',
                87  => 0,
                118 => 1,
                95 =>
                  'DISK WARNING - free space: /srv/released 14253 MB (9% inode=99%):',
                5 => '',
                6 => '',
            },
        ],
        221 => [
            {
                1   => 604,
                2   => 0,
                3   => 0,
                4   => 1353330301.664660,
                89  => 1,
                117 => 1353330301.664659,
                33  => 0.0,
                53  => 'bob',
                114 => 'Unix disk: /srv/released',
                134 => 'admin/02test-snp',
                127 => 'notify-by-email',
                13  => '',
                87  => 0,
                118 => 1,
                95 =>
                  'DISK WARNING - free space: /srv/released 14253 MB (9% inode=99%):',
                5 => '',
                6 => '',
            },
        ],
        223 => [
            {
                1   => 1801,
                2   => 0,
                3   => 0,
                4   => 1353330301.664822,
                120 => 1,
                53  => 'bob',
                114 => 'Unix disk: /srv/released',
                119 => 1,
                118 => 1,
                121 => 1,
                25  => 3,
                76  => 3,
                265 => 1,
                56  => 1,
                113 => 0,
                29  => 0,
                101 => 0,
                41  => 0,
                400 => 0,
                401 => 1,
                95 =>
                  'DISK WARNING - free space: /srv/released 14253 MB (9% inode=99%):',
            },
        ],
        211 => [
            {
                1   => 1200,
                2   => 0,
                3   => 0,
                4   => 1353330301.664848,
                106 => 1353329871,
                102 => 7273,
                28  => 1,
                55  => 1353330301,
                60  => 0,
                88  => 1,
                9   => 1,
                97  => 1,
                8   => 1,
                96  => 1,
                39  => 1,
                47  => 1,
                45  => 1,
                103 => 1,
                92  => 0,
                94  => 0,
                78  => 1,
                80  => 1,
                49  => '',
                50  => '',
            },
        ],
        411 => [
            {
                4   => 1353329871.692466,
                133 => 'hostgroup101_servicegroup93',
                131 => 'hostgroup101_servicegroup93',
                132 => [qw( test123 test1 admin)],
            },
        ],
        200 => [
            {
                1   => 106,
                2   => 0,
                3   => 0,
                4   => 1326199837.510695,
                105 => 'Nagios',
                107 => '3.2.3',
                104 => '10-03-2010',
                102 => 4776,
            },
            {
                1   => 102,
                2   => 2,
                3   => 4,
                4   => 1326199837.510721,
                105 => 'Nagios',
                107 => '3.2.3',
                104 => '10-03-2010',
                102 => 4776,
            },

            #           {
            #               1 => 104,
            #               2 => 0,
            #               3 => 0,
            #               4 => 1326199837.938116,
            #               105 => 'Nagios',
            #               107 => '3.2.3',
            #               104 => '10-03-2010',
            #               102 => 4776,
            #           },
            {
                1   => 100,
                2   => 0,
                3   => 0,
                4   => 1326199839.264677,
                105 => 'Nagios',
                107 => '3.2.3',
                104 => '10-03-2010',
                102 => 4776,
            }
        ],
        400 => [
            {
                4   => 1326199839.860049,
                174 => 'host123',
                258 => 'host123',
                159 => 'host123',
                158 => 'www.domain.com',
                160 => '',
                163 => '',
                177 => '24x7',
                162 => '24x7',
                166 => '',
                161 => 0.000000,
                247 => 1.000000,
                173 => 2,
                246 => 0.000000,
                176 => 60.000000,
                189 => 1,
                192 => 1,
                191 => 1,
                190 => 1,
                248 => 0,
                167 => 1,
                251 => 1,
                252 => 1,
                253 => 1,
                183 => 0.000000,
                156 => 0.000000,
                230 => 0,
                228 => 0,
                229 => 0,
                168 => 0,
                169 => 0,
                201 => 1,
                8   => 1,
                96  => 1,
                164 => 0,
                204 => 1,
                203 => 1,
                178 => 1,
                165 => 1,
                91  => 0,
                186 => '',
                187 => '',
                126 => '/info/host/123',
                179 => 'network_cloud.png',
                180 => 'SYMBOL - Network Cloud',
                239 => 'network_cloud.png',
                235 => 'network_cloud.png',
                154 => 0,
                240 => -1,
                242 => -1,
                155 => 0,
                241 => 0.000000,
                243 => 0.000000,
                244 => 0.000000,
                200 => ['master.host'],
                130 => [
                    qw(
                      keyword_84 keyword_83 keyword_32 keyword_31
                      keyword_210 keyword_202 keyword_196
                      hostgroup139_servicegroup63
                      )
                ],
            }
        ],
        402 => [
            {
                4   => 1326199839.860049,
                174 => 'host123',
                258 => 'host123 check',
                210 => 'host123 check',
                207 => 'set_to_stale',
                211 => '',
                224 => '24x7',
                209 => '24x7',
                214 => '',
                208 => 5.000000,
                226 => 1.000000,
                185 => 3,
                246 => 0.000000,
                223 => 60.000000,
                196 => 1,
                197 => 1,
                193 => 1,
                195 => 1,
                194 => 1,
                249 => 0,
                232 => 0,
                234 => 0,
                233 => 0,
                231 => 0,
                221 => 0,
                215 => 1,
                254 => 1,
                255 => 1,
                256 => 1,
                257 => 1,
                184 => 0.000000,
                157 => 0.000000,
                202 => 1,
                216 => 1,
                217 => 0,
                97  => 1,
                212 => 1,
                9   => 0,
                206 => 1,
                205 => 1,
                225 => 1,
                93  => 0,
                213 => 1,
                186 => 'check host123',
                187 => '/graph?host=$HOSTNAME$&service=$SERVICEDESC$',
                126 => '',
                179 => 'graph.png',
                180 => 'View graphs',
                130 => [
                    qw(
                      keyword_202 keyword_31 keyword_196
                      keyword_83 keyword_210 keyword_32 keyword_84
                      hostgroup139_servicegroup63
                      )
                ],
            }
        ],
        410 => [
            {
                4   => 1326199839.860049,
                134 => 'dummyuser/01email-for-dummyuser',
                129 => 'Dummy User',
                138 => 'dummy.user@domain.com',
                198 => '',
                177 => '24x7',
                224 => '24x7',
                225 => 1,
                178 => 1,
                250 => 1,
                196 => 1,
                197 => 1,
                193 => 1,
                195 => 1,
                194 => 1,
                249 => 0,
                189 => 1,
                192 => 1,
                191 => 1,
                190 => 1,
                248 => 0,
                128 => [qw( 1: 2: 3: 4: 5: 6: )],
                175 => 'notify-by-email',
                222 => 'notify-by-email',
            }
        ],
        401 => [
            {
                4   => 1326199839.860049,
                172 => 'HG 1',
                170 => 'HG 1',
                171 => [
                    qw(
                      h1.hg1.local
                      h2.hg1.local
                      h3.hg1.local
                      h4.hg1.local
                      )
                ],
            }
        ],
        409 => [
            {
                4   => 1326199839.860049,
                237 => 'workhours',
                236 => 'Working Hours',
                238 => [
                    qw(
                      1:32400-63000
                      2:32400-63000
                      3:32400-63000
                      4:32400-63000
                      5:32400-63000
                      )
                ],
            }
        ],
        207 => [
            {
                1   => 801,
                2   => 0,
                3   => 0,
                4   => 1353330465.249306,
                53  => 'ov-build-hardy-32',
                12  => 0,
                25  => 1,
                76  => 2,
                121 => 1,
                118 => 0,
                123 => 30,
                127 => '',
                13  => '',
                14  => '',
                117 => 1353330464.0,
                33  => 1353330465.249305,
                32  => 0,
                42  => 0.00000,
                71  => 0.28608,
                110 => 0,
                95  => 'OK - ov-build-hardy-32: rta 0.376ms, lost 0%',
                99 =>
                  'rta=0.376ms;500.000;1000.000;0; pl=0%;80;100;; rtmax=0.522ms;;;; rtmin=0.324ms;;;;',
            },
        ],
        408 => [
            {
                4   => 1326199839.860049,
                127 => 'check_f5_system_v10',
                14  => '/usr/local/nagios/libexec/check_f5_system_v10 $ARG1$',
            },
        ],
        209 => [
            {
                1   => 1102,
                2   => 0,
                3   => 0,
                4   => 1326199839.855585,
                30  => 1,
                53  => 'ov-build-hardy-32',
                114 => 'Paging File Utilisation',
                34  => 1314778856,
                10  => 'dummyuser',
                17  => "Host moved to new location",
                117 => 1314778834,
                33  => 1346314834,
                46  => 1,
                31  => 31536000,
                124 => 0,
                29  => 8978,
            },
        ],
        212 => [
            {
                1  => 1201,
                2  => 0,
                3  => 0,
                4  => 1326199839.855585,
                53 => 'ov-build-hardy-32',
                95 =>
                  'CRITICAL - 1.2.3.4 Host unreachable @ 1.2.3.4. rta nan, lost 100%',
                99 =>
                  'rta=0.000ms;500.000;1000.000;0; pl=100%;80;100;; rtmax=0.000ms;;;; rtmin=0.000ms;;;;',
                27  => 1,
                51  => 1,
                115 => 1,
                25  => 2,
                76  => 2,
                58  => 1344959397,
                81  => 0,
                12  => 1,
                63  => 1340638821,
                57  => 1340638821,
                56  => 1,
                69  => 1338518453,
                65  => 1344959399,
                68  => 1337149615,
                121 => 1,
                59  => 1353326549,
                82  => 1353330149,
                85  => 0,
                88  => 1,
                101 => 0,
                7   => 0,
                26  => 743,
                96  => 1,
                38  => 0,
                8   => 0,
                47  => 1,
                54  => 0,
                98  => 0.00000,
                71  => 0.81100,
                42  => 0.00000,
                113 => 0,
                45  => 1,
                103 => 1,
                91  => 0,
                78  => 0,
                37  => '',
                11  => '',
                86  => 0.000000,
                109 => 0.000000,
                162 => '24x7',
            }
        ],
        219 => [
            {
                1 => 1602,
                2 => 0,
                3 => 0,
                4 => 1326199837.510727,
            }
        ],
        222 => [
            {
                1   => 1700,
                2   => 0,
                3   => 0,
                4   => 1326199839.860049,
                7   => 1,
                53  => 'ov-build-hardy-32',
                114 => 'Paging File Utilisation',
                10  => 'dummyuser',
                17  => 'acknowledged',
                118 => 2,
                122 => 0,
                100 => 0,
                90  => 0,
            }
        ],
        224 => [
            {
                1   => 1203,
                2   => 0,
                3   => 0,
                4   => 1326199839.849463,
                134 => 'dummyuser',
                178 => 1,
                225 => 1,
                59  => 0,
                62  => 0,
                261 => 0,
                78  => 0,
                80  => 0,
            },
        ],
        208 => [
            {
                1   => 902,
                2   => 0,
                3   => 0,
                4   => 1353329871.692064,
                20  => 2,
                53  => 'ov-build-hardy-32',
                114 => 'Paging File Utilisation',
                34  => 1314778856,
                10  => 'dummyuser',
                17  => 'Problem acknowleged via REST API by dummyuser',
                100 => 0,
                116 => 0,
                35  => 4,
                44  => 0,
                43  => 0,
                18  => 26714,
            }
        ],
        405 => [
            {
                4   => 1326199839.860049,
                174 => 'ov-build-hardy-32',
                210 => 'Opsview Agent',
                136 => 'ov-build-hardy-32',
                137 => 'Paging File Utilisation',
                135 => 2,
                181 => 0,
                259 => '',
                148 => 0,
                152 => 1,
                149 => 1,
                146 => 1,
            },
        ],
    ];
    my $events = [];
    for ( my $i = 0; $i < @$_events; $i += 2 ) {
        $events->[$i] = $_events->[$i];
        $events->[ $i + 1 ] = [];

        for my $e ( @{ $_events->[ $i + 1 ] } ) {
            my $d = [];
            $d->[$_] = $e->{$_} for keys %$e;
            push @{ $events->[ $i + 1 ] }, $d;
        }
    }

    {
        my $events_handlers_counts = {};
        my %event2handler_map;
        for ( my $i = 0; $i < @$events; $i += 2 ) {
            my $event_id = $events->[$i];

            #$DB::single = 1;
            my $handler_name = $self->{importer}->{event_handlers}->[$event_id];
            diag "$event_id => $handler_name";

            $event2handler_map{$event_id} = $handler_name;

            $events_handlers_counts->{$event_id} = [
                0 => 0, # method_called => number_of_events
                $handler_name, # name_of_handler
            ];
        }

        my $run_once = 0;
        my $mock     = $self->mock(
            $self->{importer},
            parse_c => sub {
                return $run_once++ ? undef : $events;
            },
            (
                map {
                    my $event_num    = $_;
                    my $handler_name = $event2handler_map{$event_num};

                    (
                        $handler_name => sub {
                            my ( $this, $events ) = @_;
                            $events_handlers_counts->{$event_num}->[0] += 1;
                            $events_handlers_counts->{$event_num}->[1]
                              += scalar @$events;
                        }
                      )
                } keys %event2handler_map
            )
        );
        $DB::single = 1;
        my $res = $self->{importer}->send_log( $self->{file}, 123 );

        for ( my $i = 0; $i < @$events; $i += 2 ) {
            my $type = $events->[$i];
            my $data = $events->[ $i + 1 ];
            $events_handlers_counts->{$type}->[0] -= 1;
            $events_handlers_counts->{$type}->[1] -= scalar @$data;
        }

        while ( my ( $type, $counts ) = each %$events_handlers_counts ) {
            my $called       = $events_handlers_counts->{$type}->[0];
            my $events_count = $events_handlers_counts->{$type}->[1];
            my $name         = $events_handlers_counts->{$type}->[2];
            is( $called,       0, "$name was called correct number of times" );
            is( $events_count, 0, "...with correct number of events" );
        }
    }

    {
        my $run_once = 0;
        my $mock     = $self->mock(
            $self->{importer},
            parse_c => sub {
                return $run_once++ ? undef : $events;
            },
        );

        my $mysqldump =
          "mysqldump --compatible=mysql40 --skip-extended-insert --comments=FALSE --complete-insert=FALSE --order-by-primary=TRUE --quote-names -u "
          . Opsview::Config->runtime_dbuser . " -p"
          . Opsview::Config->runtime_dbpasswd . " "
          . Opsview::Config->runtime_db;

        my ( $db_before, $db_after ) =
          qw(t/var/runtime.db.dump.before t/var/runtime.db.dump.after);
        my ( $diff_got, $diff_exp ) =
          qw( t/var/ndologs/log-imported.diff.got t/var/ndologs/log-imported.diff.expected );

        is(
            system("$mysqldump | grep ^INSERT > $db_before"),
            0, "mysqldump finished"
        );

        my $res = $self->{importer}->send_log( $self->{file}, 123 );

        is(
            system("$mysqldump | grep ^INSERT > $db_after"),
            0, "mysqldump finished"
        );

        is(
            $self->{importer}->{loading_retention_data_flag},
            undef,
            "NDO_API_RETENTIONDATA (219) ignores NEBTYPE_RETENTIONDATA_STARTSAVE()"
        );

        system(
            "diff -u $db_before $db_after | grep -v runtime.db.dump > t/var/ndologs/log-imported.diff.got"
        );

        #system("cp -v $diff_got $diff_exp");

        is( system("diff -q $diff_exp $diff_got"),
            0, "Got expected database changes" )
          or do {
            print "\n\n\ndiff -u $db_before $db_after\n";
            system( "diff -u $db_before $db_after | grep -v runtime.db.dump" );
            print "\n\n\ndiff -u $diff_exp $diff_got\n";
            system( "diff -u $diff_exp $diff_got" );
          };

        #unlink($_) for ( $db_before, $db_after, $diff_got );
    }
}

1;

