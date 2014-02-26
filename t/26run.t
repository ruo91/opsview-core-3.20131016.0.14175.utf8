#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 141;
use Test::LongString;

use FindBin qw($Bin);
use lib "$Bin/../lib", "t/lib";

use_ok( "Opsview::Run" );

my ( $rc, $out, $err, $out_expected, $err_expected );

diag("problem command") if ( $ENV{TEST_VERBOSE} );
( $rc, $out, $err ) = Opsview::Run->run_command( "/bin/not-there" );
is( $@,   "file not found: /bin/not-there", "@='$@'" );
is( $rc,  undef,                            "return code correct" );
is( $out, undef,                            "stdout correct" );
is( $err, undef,                            "stderr correct" );

diag("simple command with no output, returns 0") if ( $ENV{TEST_VERBOSE} );
( $rc, $out, $err ) = Opsview::Run->run_command( "/bin/true" );
is( $@,   "",    "@='$@'" );
is( $rc,  0,     "return code correct" );
is( $out, undef, "stdout correct" );
is( $err, undef, "stderr correct" );

diag("simple command with no output, returns 1") if ( $ENV{TEST_VERBOSE} );
( $rc, $out, $err ) = Opsview::Run->run_command( "/bin/false" );
is( $@,   "",    "@='$@'" );
is( $rc,  1,     "return code correct" );
is( $out, undef, "stdout correct" );
is( $err, undef, "stderr correct" );

diag("simple command with large output") if ( $ENV{TEST_VERBOSE} );
my $contents = "abcd\n" x 10000;
( $rc, $out, $err ) =
  Opsview::Run->run_command( "perl", "-e", 'print "abcd\n" x 10000' );
is( $@,  "", "@='$@'" );
is( $rc, 0,  "return code correct" );
my $output = join( "", @$out );
is_string( $output, $contents, "stdout correct" );
is( $err, undef, "stderr correct" );

diag("complex command with problem")
  if ( $ENV{TEST_VERBOSE} );
( $rc, $out, $err ) = Opsview::Run->run_command( "/var" );
is( $@,   "exec failed: Permission denied", "@='$@'" );
is( $rc,  undef,                            "return code correct" );
is( $out, undef,                            "stdout correct" );
is( $err, undef,                            "stderr correct" );

diag("complex command with one line of STDOUT output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e", 'print STDOUT "this is a test\n"' );
is( $@,        "",                 "@='$@'" );
is( $rc,       0,                  "return code correct" );
is( $out->[0], "this is a test\n", "stdout correct" );
is( $err,      undef,              "stderr correct" );

diag("complex command with one line of STDOUT output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e",
    'print STDOUT "this is a test\n"; exit 5'
  );
is( $@,        "",                 "@='$@'" );
is( $rc,       5,                  "return code correct" );
is( $out->[0], "this is a test\n", "stdout correct" );
is( $err,      undef,              "stderr correct" );

diag("complex command with mutiple lines of STDOUT output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
$out_expected = [ "line1\n", "line2\n", "line3\n", ];
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e",
    'print STDOUT "line1\nline2\nline3\n"'
  );
is( $@,  "", "@='$@'" );
is( $rc, 0,  "return code correct" );
is_deeply( $out, $out_expected, "stdout correct" );
is( $err, undef, "stderr correct" );

diag("complex command with mutiple lines of STDOUT output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
$out_expected = [ "line1\n", "line2\n", "line3\n", ];
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e",
    'print STDOUT "line1\nline2\nline3\n" ; exit 5'
  );
is( $@,  "", "@='$@'" );
is( $rc, 5,  "return code correct" );
is_deeply( $out, $out_expected, "stdout correct" );
is( $err, undef, "stderr correct" );

diag("complex command with one line of STDERR output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e", 'print STDERR "this is a test\n"' );
is( $@,        "",                 "@='$@'" );
is( $rc,       0,                  "return code correct" );
is( $out,      undef,              "stdout correct" );
is( $err->[0], "this is a test\n", "stderr correct" );

diag("complex command with one line of STDERR output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e",
    'print STDERR "this is a test\n" ; exit 5'
  );
is( $@,        "",                 "@='$@'" );
is( $rc,       5,                  "return code correct" );
is( $out,      undef,              "stdout correct" );
is( $err->[0], "this is a test\n", "stderr correct" );

diag("complex command with mutiple lines of STDERR output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
$err = [ "line1\n", "line2\n", "line3\n", ];
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e",
    'print STDERR "line1\nline2\nline3\n"'
  );
is( $@,   "",    "@='$@'" );
is( $rc,  0,     "return code correct" );
is( $out, undef, "stdout correct" );
is_deeply( $err, $err, "stderr correct" );

diag("complex command with mutiple lines of STDERR output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
$err = [ "line1\n", "line2\n", "line3\n", ];
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e",
    'print STDERR "line1\nline2\nline3\n" ; exit 5'
  );
is( $@,   "",    "@='$@'" );
is( $rc,  5,     "return code correct" );
is( $out, undef, "stdout correct" );
is_deeply( $err, $err, "stderr correct" );

diag("complex command with single lines of STDOUT and STDERR output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
$out_expected = ["stdout\n"];
$err_expected = ["stderr\n"];
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e",
    'print STDOUT "stdout\n"; print STDERR "stderr\n" ; exit 0'
  );
is( $@,  "", "@='$@'" );
is( $rc, 0,  "return code correct" );
is_deeply( $out, $out_expected, "stdout correct" );
is_deeply( $err, $err_expected, "stderr correct" );

diag("complex command with single lines of STDOUT and STDERR output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
$out_expected = ["stdout\n"];
$err_expected = ["stderr\n"];
( $rc, $out, $err ) =
  Opsview::Run->run_command( "$^X", "-e",
    'print STDOUT "stdout\n"; print STDERR "stderr\n" ; exit 5'
  );
is( $@,  "", "@='$@'" );
is( $rc, 5,  "return code correct" );
is_deeply( $out, $out_expected, "stdout correct" );
is_deeply( $err, $err_expected, "stderr correct" );

diag(
    "complex command with multiple lines of STDOUT and STDERR output, returns 0"
) if ( $ENV{TEST_VERBOSE} );
$out_expected = [ "stdout1\n", "stdout2\n", "stdout3\n", ];
$err_expected = [ "stderr1\n", "stderr2\n", "stderr3\n" ];
( $rc, $out, $err ) = Opsview::Run->run_command(
    "$^X",
    "-e",
    'print STDOUT "stdout1\nstdout2\nstdout3\n"; print STDERR "stderr1\nstderr2\nstderr3\n" ; exit 0'
);
is( $@,  "", "@='$@'" );
is( $rc, 0,  "return code correct" );
is_deeply( $out, $out_expected, "stdout correct" );
is_deeply( $err, $err_expected, "stderr correct" );

diag(
    "complex command with multiple lines of STDOUT and STDERR output, returns 5"
) if ( $ENV{TEST_VERBOSE} );
$out_expected = [ "stdout1\n", "stdout2\n", "stdout3\n", ];
$err_expected = [ "stderr1\n", "stderr2\n", "stderr3\n", ];
( $rc, $out, $err ) = Opsview::Run->run_command(
    "$^X",
    "-e",
    'print STDOUT "stdout1\nstdout2\nstdout3\n"; print STDERR "stderr1\nstderr2\nstderr3\n" ; exit 5'
);
is( $@,  "", "@='$@'" );
is( $rc, 5,  "return code correct" );
is_deeply( $out, $out_expected, "stdout correct" );
is_deeply( $err, $err_expected, "stderr correct" );

#===#
sub capture_out {
    $out .= $_[0];
}

sub capture_err {
    $err .= $_[0];
}
diag("problem capture command") if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap( ["/bin/not-there"], \&capture_out, \&capture_err );
is( $@,   "file not found: /bin/not-there", "@='$@'" );
is( $rc,  undef,                            "return code correct" );
is( $out, undef,                            "stdout correct" );
is( $err, undef,                            "stderr correct" );

diag("simple capture command with no output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap( ["/bin/true"], \&capture_out, \&capture_err );
is( $@,   "",    "@='$@'" );
is( $rc,  0,     "return code correct" );
is( $out, undef, "stdout correct" );
is( $err, undef, "stderr correct" );

diag("simple capture command with no output, returns 1")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap( ["/bin/false"], \&capture_out, \&capture_err );
is( $@,   "",    "@='$@'" );
is( $rc,  1,     "return code correct" );
is( $out, undef, "stdout correct" );
is( $err, undef, "stderr correct" );

diag("complex capture command with problem")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap( ["/var"], \&capture_out, \&capture_err );
is( $@,   "exec failed: Permission denied", "@='$@'" );
is( $rc,  undef,                            "return code correct" );
is( $out, undef,                            "stdout correct" );
is( $err, undef,                            "stderr correct" );

diag("complex capture command with one line of STDOUT output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap( [ "$^X", "-e", 'print STDOUT "this is a test\n"' ],
    \&capture_out, \&capture_err );
is( $@,   "",                 "@='$@'" );
is( $rc,  0,                  "return code correct" );
is( $out, "this is a test\n", "stdout correct" );
is( $err, undef,              "stderr correct" );

diag("complex capture command with one line of STDOUT output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap(
    [ "$^X", "-e", 'print STDOUT "this is a test\n"; exit 5' ],
    \&capture_out, \&capture_err );
is( $@,   "",                 "@='$@'" );
is( $rc,  5,                  "return code correct" );
is( $out, "this is a test\n", "stdout correct" );
is( $err, undef,              "stderr correct" );

diag("complex capture command with mutiple lines of STDOUT output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc =
  run_command_subcap( [ "$^X", "-e", 'print STDOUT "line1\nline2\nline3\n"' ],
    \&capture_out, \&capture_err );
is( $@,   "",                        "@='$@'" );
is( $rc,  0,                         "return code correct" );
is( $out, qq{line1\nline2\nline3\n}, "stdout correct" );
is( $err, undef,                     "stderr correct" );

diag("complex capture command with mutiple lines of STDOUT output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap(
    [ "$^X", "-e", 'print STDOUT "line1\nline2\nline3\n" ; exit 5' ],
    \&capture_out, \&capture_err );
is( $@,   "",                        "@='$@'" );
is( $rc,  5,                         "return code correct" );
is( $out, qq{line1\nline2\nline3\n}, "stdout correct" );
is( $err, undef,                     "stderr correct" );

diag("complex capture command with one line of STDERR output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap( [ "$^X", "-e", 'print STDERR "this is a test\n"' ],
    \&capture_out, \&capture_err );
is( $@,   "",                 "@='$@'" );
is( $rc,  0,                  "return code correct" );
is( $out, undef,              "stdout correct" );
is( $err, "this is a test\n", "stderr correct" );

diag("complex capture command with one line of STDERR output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap(
    [ "$^X", "-e", 'print STDERR "this is a test\n" ; exit 5' ],
    \&capture_out, \&capture_err );
is( $@,   "",                 "@='$@'" );
is( $rc,  5,                  "return code correct" );
is( $out, undef,              "stdout correct" );
is( $err, "this is a test\n", "stderr correct" );

diag("complex capture command with mutiple lines of STDERR output, returns 0")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc =
  run_command_subcap( [ "$^X", "-e", 'print STDERR "line1\nline2\nline3\n"' ],
    \&capture_out, \&capture_err );
is( $@,   "",                        "@='$@'" );
is( $rc,  0,                         "return code correct" );
is( $out, undef,                     "stdout correct" );
is( $err, qq{line1\nline2\nline3\n}, "stderr correct" );

diag("complex capture command with mutiple lines of STDERR output, returns 5")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap(
    [ "$^X", "-e", 'print STDERR "line1\nline2\nline3\n" ; exit 5' ],
    \&capture_out, \&capture_err );
is( $@,   "",                      "@='$@'" );
is( $rc,  5,                       "return code correct" );
is( $out, undef,                   "stdout correct" );
is( $err, "line1\nline2\nline3\n", "stderr correct" );

diag(
    "complex capture command with single lines of STDOUT and STDERR output, returns 0"
) if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap(
    [
        "$^X", "-e", 'print STDOUT "stdout\n"; print STDERR "stderr\n" ; exit 0'
    ],
    \&capture_out,
    \&capture_err
);
is( $@,   "",         "@='$@'" );
is( $rc,  0,          "return code correct" );
is( $out, "stdout\n", "stdout correct" );
is( $err, "stderr\n", "stderr correct" );

diag(
    "complex capture command with single lines of STDOUT and STDERR output, returns 5"
) if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$out_expected = ["stdout\n"];
$err_expected = ["stderr\n"];
$rc           = run_command_subcap(
    [
        "$^X", "-e", 'print STDOUT "stdout\n"; print STDERR "stderr\n" ; exit 5'
    ],
    \&capture_out,
    \&capture_err
);
is( $@,   "",         "@='$@'" );
is( $rc,  5,          "return code correct" );
is( $out, "stdout\n", "stdout correct" );
is( $err, "stderr\n", "stderr correct" );

diag(
    "complex capture command with multiple lines of STDOUT and STDERR output, returns 0"
) if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$out_expected = [ "stdout1\n", "stdout2\n", "stdout3\n" ];
$err_expected = [ "stderr1\n", "stderr2\n", "stderr3\n" ];
$rc           = run_command_subcap(
    [
        "$^X",
        "-e",
        'print STDOUT "stdout1\nstdout2\nstdout3\n"; print STDERR "stderr1\nstderr2\nstderr3\n" ; exit 0'
    ],
    \&capture_out,
    \&capture_err
);
is( $@,  "", "@='$@'" );
is( $rc, 0,  "return code correct" );
is_deeply( $out, "stdout1\nstdout2\nstdout3\n", "stdout correct" );
is_deeply( $err, "stderr1\nstderr2\nstderr3\n", "stderr correct" );

diag(
    "complex capture command with multiple lines of STDOUT and STDERR output, returns 5"
) if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap(
    [
        "$^X",
        "-e",
        'print STDOUT "stdout1\nstdout2\nstdout3\n"; print STDERR "stderr1\nstderr2\nstderr3\n" ; exit 5'
    ],
    \&capture_out,
    \&capture_err
);
is( $@,  "", "@='$@'" );
is( $rc, 5,  "return code correct" );
is_deeply( $out, "stdout1\nstdout2\nstdout3\n", "stdout correct" );
is_deeply( $err, "stderr1\nstderr2\nstderr3\n", "stderr correct" );

diag("Check output over 10000 bytes")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$out_expected = "123456\n" x 2000;
$err_expected = undef;
$rc           = run_command_subcap( [ "$^X", "-e", 'print "123456\n" x 2000' ],
    \&capture_out, \&capture_err );
is( $@,  "", "@='$@'" );
is( $rc, 0,  "return code correct" );
is_string( $out, $out_expected, "stdout correct" );
is( $err, $err_expected, "stderr correct" );

diag("Check stderr over 10000 bytes")
  if ( $ENV{TEST_VERBOSE} );
$err = $out = undef;
$rc = run_command_subcap( [ "$^X", "-e", 'print STDERR "123456\n" x 2000' ],
    \&capture_out, \&capture_err );
is( $@,  "", "@='$@'" );
is( $rc, 0,  "return code correct" );
is_string( $out, undef,             "stdout correct" );
is_string( $err, "123456\n" x 2000, "stderr correct" );
