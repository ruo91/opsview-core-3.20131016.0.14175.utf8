#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "t/lib", "$Bin/../etc", "$Bin/../lib";
use Test::DatabaseRow;
use Test::Warn;
use Test::Exception;
use Test::File;
use File::Temp qw(tempdir);
use_ok( "Utils::Hosticon" );

my $icon;

dies_ok { $icon = Utils::Hosticon->new() } 'No source icon passed';

dies_ok { $icon = Utils::Hosticon->new( { image_dir => '/doesnt_exist' } ) }
'Target image directory does not exist';

dies_ok { $icon = Utils::Hosticon->new( { source => 'fred.png' } ) }
'Source image does not exist';

sub run_tests {
    my $temp_dir = tempdir( CLEANUP => 1 );

    $icon = Utils::Hosticon->new(
        {
            image_dir => $temp_dir,
            source    => $Bin . '/var/test.png'
        }
    );
    isa_ok( $icon, "Utils::Hosticon", "Created okay" );
    is(
        $icon->get_source_image,
        $Bin . '/var/test.png',
        'source image retrieved'
    );
    is( $icon->get_image_basename, 'test', 'image basename retrieved' );
    is(
        $icon->get_image_full_basename,
        $temp_dir . '/test',
        'image full basename retrieved'
    );

    dies_ok { $icon->_check_if_exists } 'No file type provided';
    dies_ok { $icon->_check_prereqs } 'No file source provided';
    dies_ok { $icon->_check_prereqs('src') } 'No file dest provided';
    dies_ok { $icon->_check_prereqs( 'src', 'dst' ) }
    'source doesnt exist - has it been converted?';
    dies_ok { $icon->convert_to_png }
    'source doesnt exist - has it been converted?';

    file_not_exists_ok( $temp_dir . '/test.png', 'test.png doesnt exist' );
    is( $icon->_check_if_exists('.png'), 0, 'internal png exist check ok' );
    $icon->install_png;
    file_exists_ok( $temp_dir . '/test.png', 'test.png exists' );
    is( $icon->_check_if_exists('.png'), 1, 'internal png exist check ok' );

    file_not_exists_ok( $temp_dir . '/test_small.png' );
    is( $icon->_check_if_exists('_small.png'), 0, 'internal exist check ok' );
    ok( $icon->convert_to_small_png, 'calling convert_to_small_png' );
    file_exists_ok( $temp_dir . '/test_small.png' );
    is( $icon->_check_if_exists('_small.png'), 1, 'internal exist check ok' );
}

run_tests(0);

my $temp_dir = tempdir( CLEANUP => 1 );

$icon = Utils::Hosticon->new(
    {
        image_dir => $temp_dir,
        source    => $Bin . '/var/test.png'
    }
);
isa_ok( $icon, "Utils::Hosticon", "Created okay" );

file_not_exists_ok( $temp_dir . '/test' . $_, 'test' . $_ . ' doesnt exist' )
  for (qw/ .png _small.png/);
$icon->setup_all;
file_exists_ok( $temp_dir . '/test' . $_, 'test' . $_ . ' exists ok' )
  for (qw/  .png _small.png/);

# ensure basename set correctly when source image has no path
$icon = undef;
chdir($temp_dir) || die( 'Couldnt chdir to ', $temp_dir );
$icon = Utils::Hosticon->new(
    {
        image_dir => $temp_dir,
        source    => 'test.png'
    }
);
isa_ok( $icon, "Utils::Hosticon", "Created okay" );
is( $icon->get_image_basename, 'test', 'image basename retrieved' );
is(
    $icon->get_image_full_basename,
    $temp_dir . '/test',
    'image full basename retrieved'
);

# ensure back out of directory for when its removed
chdir( '/' );
