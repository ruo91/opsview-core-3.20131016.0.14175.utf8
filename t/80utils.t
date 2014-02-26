#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use Opsview::Utils
  qw(escape_xml_data convert_to_arrayref convert_state_type_to_text convert_perl_regexp_to_js_string apidatatidy get_ssh_version convert_text_to_state_type);
use Opsview::Utils::Time;

$_ = 'funny$snmpstring';
is(
    Opsview::Utils->cleanup_args_for_nagios($_),
    'funny$$snmpstring', 'Nagios escaped $'
);
$_ = 'nowtelse';
is(
    Opsview::Utils->cleanup_args_for_nagios($_),
    'nowtelse', 'Nagios no escape'
);
$_ = undef;
is( Opsview::Utils->cleanup_args_for_nagios($_), '', 'Empty string' );
$_ = "";
is( Opsview::Utils->cleanup_args_for_nagios($_), '', 'Empty string' );
$_ = 0;
is( Opsview::Utils->cleanup_args_for_nagios($_), '0', '0 as expected' );
$_ = 'mostpercul!ar$nmpcommun!ty$tring';
is(
    Opsview::Utils->cleanup_args_for_nagios($_),
    'mostpercul\!ar$$nmpcommun\!ty$$tring',
    '0 as expected'
);

$_ = "my trouble this store's room";
is(
    Opsview::Utils->make_shell_friendly($_),
    "'my trouble this store'\"'\"'s room'",
    "escaped '"
);
$_ = "normal";
is( Opsview::Utils->make_shell_friendly($_), "'normal'", "no fuss" );
$_ = 'all^ & $ ! ';
is(
    Opsview::Utils->make_shell_friendly($_),
    "'all\^ \& \$ \! '",
    "escaped correctly"
);
$_ = undef;
is( Opsview::Utils->make_shell_friendly($_), "''", "Empty quoted string" );
$_ = "";
is( Opsview::Utils->make_shell_friendly($_), "''", "Empty string again" );
$_ = 0;
is( Opsview::Utils->make_shell_friendly($_), "'0'", "'0' as expected" );

$_ = 'funny!string';
is( Opsview::Utils->escape_shriek($_), 'funny\!string', 'escaped !' );
$_ = 'funny\!string';
is( Opsview::Utils->escape_shriek($_), 'funny\!string', 'left alone \!' );

$_ = 'funny!!string';
is( Opsview::Utils->escape_shriek($_), 'funny\!\!string', 'escaped !!' );
$_ = 'funny\!\!string';
is( Opsview::Utils->escape_shriek($_), 'funny\!\!string', 'left alone \!\!' );

$/ = "";
while (<DATA>) {
    my ( $initial, $expected ) = split( "\n", $_ );
    my $converted = escape_xml_data($initial);
    is( $converted, $expected, "Converted: $initial" );
}

is_deeply(
    convert_to_arrayref("bob"),
    ["bob"], "Convert single item correctly"
);
is_deeply(
    convert_to_arrayref( [ "A", "2", "c" ] ),
    [ "A", "2", "c" ],
    "Convert list correctly"
);
is_deeply( convert_to_arrayref(), [], "Convert empty list correctly" );

is( convert_state_type_to_text(0), "soft", "Soft state type ok" );
is( convert_state_type_to_text(1), "hard", "Hard ok" );
eval { convert_state_type_to_text() };
like( $@, qr/Missing state type/, "Got empty state type" );

is( convert_text_to_state_type("soft"),    0,     "Soft state type ok" );
is( convert_text_to_state_type("hard"),    1,     "Hard ok" );
is( convert_text_to_state_type("HaRd"),    1,     "Hard ok with mixed case" );
is( convert_text_to_state_type("rubbish"), undef, "Undef for invalid values" );
eval { convert_text_to_state_type() };
like( $@, qr/Missing state type/, "Got empty state type" );

eval { convert_state_type_to_text(2) };
like( $@, qr/Invalid state type/, "Got invalid state type" );

my %tests = (
    "54s"    => "54",
    "2h 5m"  => 7500,
    "1d"     => 86400,
    "7d"     => 604800,
    "7d 23s" => 604823,
    "3d 10m" => 259800,
);

foreach my $j ( keys %tests ) {
    is(
        Opsview::Utils::Time->jira_duration_to_seconds($j),
        $tests{$j}, "Converting from jira: $j"
    );
    is(
        Opsview::Utils::Time->seconds_to_jira_duration( $tests{$j} ),
        $j, "Converting to jira: $tests{$j}"
    );
}

eval { $_ = Opsview::Utils::Time->jira_duration_to_seconds("badrobot") };
like( $@, qr/badrobot not wellformed. <duration><wdhms>/, "Bad input croaks" );

is(
    Opsview::Utils::Time->seconds_to_jira_duration(-5),
    "", "Negative values give empty string"
);
is(
    Opsview::Utils::Time->seconds_to_jira_duration("unparseable"),
    "", "As does non values"
);

my $re_tests = [
    {
        re => qr/^[A-Z]+$/,
        ex => '/^[A-Z]+$/',
    },
    {
        re => qr/^[\w\.-]{1,63}$/,
        ex => '/^[\w\.-]{1,63}$/',
    }
];

foreach my $test (@$re_tests) {
    my $re = $test->{re};
    my $ex = $test->{ex};
    is( convert_perl_regexp_to_js_string($re),
        $ex, 'String conversion of ' . "$re" . ' into ' . $ex );
}

my $hash_with_refs = {
    "name" => "blah",
    "ref"  => "noblah",
    object => {
        name           => "rah!",
        ref            => "blahblah",
        another_object => {
            name => "stuff",
            ref  => "nonsense",
        },
    },
    list => [
        {
            name => "listy",
            ref  => "fun",
        },
        {
            name   => "listy2",
            ref    => "more fun",
            object => {
                name => "again",
                ref  => "morefun"
            },
            list => [
                {
                    name => "inner",
                    ref  => "circle"
                }
            ],
        },
    ],
};
my $clean_hash = {
    "name" => "blah",
    object => {
        "name"         => "rah!",
        another_object => { "name" => "stuff", },
    },
    list => [
        { name => "listy", },
        {
            name   => "listy2",
            object => { name => "again" },
            list   => [ { name => "inner" } ],
        },
    ],
};
is_deeply(
    Opsview::Utils->remove_keys_from_hash( $hash_with_refs, ["ref"] ),
    $clean_hash, "Got cleaned up hash"
);

my $dt = DateTime->new(
    year      => 2036,
    month     => 4,
    day       => 20,
    hour      => 4,
    minute    => 13,
    second    => 0,
    time_zone => "local",
);
use DateTime::Format::Strptime;
use DateTime;
my $dt_formatter = sub {
    my $dt = shift->set_formatter(
        DateTime::Format::Strptime->new(
            pattern   => "%F %T",
            time_zone => "local"
        )
    );
    "$dt";
};
my $numerics = {
    "scalar" => 42,
    "list"   => [
        {
            "a.n.other" => 33,
            "devilish"  => 666,
        }
    ],
    "hash" => {
        "key2"     => 999,
        "key1"     => 77,
        "undef"    => undef,
        "datetime" => $dt,
    },
    "listsoflists" => [ [5], [7], [11], ],
};
use JSON;
my $json = JSON->new->canonical;
use Clone qw(clone);
my $tmp = clone($numerics);

is(
    $json->encode(
        Opsview::Utils->convert_all_values_to_string( $tmp, $dt_formatter )
    ),
    qq%{"hash":{"datetime":"2036-04-20 04:13:00","key1":"77","key2":"999","undef":null},"list":[{"a.n.other":"33","devilish":"666"}],"listsoflists":[["5"],["7"],["11"]],"scalar":"42"}%,
    "Got JSON as expected"
);

$tmp = clone($numerics);
is(
    $json->encode( Opsview::Utils->convert_all_values_to_string($tmp) ),
    qq%{"hash":{"datetime":"2092277580","key1":"77","key2":"999","undef":null},"list":[{"a.n.other":"33","devilish":"666"}],"listsoflists":[["5"],["7"],["11"]],"scalar":"42"}%,
    "Got JSON as expected for datetime objects"
);

my $hash;
my $expected;
$hash = Opsview::Utils->add_me_to_columns( { "id" => { "!=" => 5 } } );
$expected = { "me.id" => { "!=" => 5 } };
is_deeply( $hash, $expected, "Got this" );

$hash = Opsview::Utils->add_me_to_columns(
    { "-and" => { "id" => [ { ">=" => 3 }, { "<=", 10 } ] } }
);
$expected = { "-and" => { "me.id" => [ { ">=" => 3 }, { "<=", 10 } ] } };
is_deeply( $hash, $expected, "Got this too" );

is(
    apidatatidy('{the=>"dogs",in=>"trouble"}'),
    qq%{ in => "trouble", the => "dogs" }%,
    "Print perl"
);
is(
    apidatatidy('{"the":"dogs","in":"trouble"}'),
    qq%{\n   "in" : "trouble",\n   "the" : "dogs"\n}\n%,
    "Print json"
);
is(
    apidatatidy("thedogsintrouble"),
    qq%thedogsintrouble%, "Unknown format same"
);

note( 'Testing parsing ssh version strings' );
my %ssh_version_strings = (
    'some rubbish'                                                 => 0.0,
    'more rubbish SSH_2.5.5.4'                                     => 0.0,
    'Sun_SSH_1.1, SSH protocols 1.5/2.0, OpenSSL 0x0090704f'       => 1.1,
    'Sun_SSH_1.1.3, SSH protocols 1.5/2.0, OpenSSL 0x0090704f'     => 1.1,
    'OpenSSH_4.3p2, OpenSSL 0.9.8e-fips-rhel5 01 Jul 2008'         => 4.3,
    'OpenSSH_4.7p1 Debian-8ubuntu3, OpenSSL 0.9.8g 19 Oct 2007'    => 4.7,
    'OpenSSH_5.1p1-hpn13v5 Debian-5.1, OpenSSL 0.9.8g 19 Oct 2007' => 5.1,
);

foreach my $string ( keys %ssh_version_strings ) {
    is(
        get_ssh_version($string),
        $ssh_version_strings{$string},
        "Parsed '$string' as '$ssh_version_strings{$string}' correctly"
    );
}
my $ssh_version;

__DATA__
The wife's dog's bowl was > my involvement but < the giraffe ("You & the penguin", he said). Never <>
The wife&apos;s dog&apos;s bowl was &gt; my involvement but &lt; the giraffe (&quot;You &amp; the penguin&quot;, he said). Never &lt;&gt;

Something already encoded &amp; in XML format
Something already encoded &amp; in XML format
