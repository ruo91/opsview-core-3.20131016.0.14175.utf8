
use Test::More tests => 36;
BEGIN { use_ok('Opsview::Utils::NDOLogsImporter::XS') }

#########################

my @timevals = (
    'invalid'           => [ 0,          0 ],
    ''                  => [ 0,          0 ],
    '1353329876.187172' => [ 1353329876, 187172 ],
    '1353330305.179876' => [ 1353330305, 179876 ],
    '1353329876'        => [ 1353329876, 0 ],
    '0.187172'          => [ 0,          187172 ],
);

# test IV/NV
push @timevals, 1353329876,       [ 1353329876, 0 ];
push @timevals, 1353329876.18717, [ 1353329876, 18717 ];
push @timevals, 1353330305.17987, [ 1353330305, 17987 ];

while ( my ( $num, $expected ) = splice( @timevals, 0, 2 ) ) {
    my $copy = "$num";
    is_deeply(
        [ Opsview::Utils::NDOLogsImporter::XS::timeval($num) ],
        $expected, "$num converted to " . join( ".", @$expected )
    );
    is_deeply(
        [ Opsview::Utils::NDOLogsImporter::XS::timeval($num) ],
        $expected, "..and can be repeated"
    );
    is( $num, $copy, "..and argument is not modified" );
}
is_deeply(
    [ Opsview::Utils::NDOLogsImporter::XS::timeval(undef) ],
    [ 0, 0 ],
    "undef converted to 0.0"
);
is_deeply(
    [ Opsview::Utils::NDOLogsImporter::XS::timeval(undef) ],
    [ 0, 0 ],
    "undef converted to 0.0"
);

my @escapes = (

    # single \
    '\\r' => "\r",

    # double \\
    '\\\\r' => '\\r',

    # quadruple \\\\
    '\\\\\\\\r' => '\\\\r',
);

for ( my $i = 0; $i < @escapes; $i += 2 ) {
    my $res      = $escapes[$i];
    my $expected = $escapes[ $i + 1 ];
    my $str      = $res;
    my $len = Opsview::Utils::NDOLogsImporter::XS::ndo_unescape_buffer($res);

    # ndo_unescape_buffer is for C only, so fake cutting the string in right place
    $res = substr( $res, 0, $len );

    is( $res, $expected,         "$str unescaped correctly" );
    is( $len, length($expected), "...and expected length returned: $len" );
}

