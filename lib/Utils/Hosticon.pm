#
#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

package Utils::Hosticon;

use strict;
use warnings;

use Carp;
use Config;
use Scalar::Util qw(refaddr);
use File::Which;
use File::Copy;

# instead of pulling new module to get one function, alias ident
# to a base available function
sub ident {
    return refaddr( $_[0] );
}

sub no_binary {
    my ($package) = @_;
    croak( 'Cannot find necessary binary - is "', $package, '" installed?' );
}

{
    my $image_dir = '/usr/local/nagios/share/images/logos';
    my %source_of;
    my %image_basename_of;

    my $bin_convert = which( 'convert' );

    # check if we have the right conversion software installed
    no_binary('imagemagick') if ( !$bin_convert );

    sub new {
        my ( $class, $args_ref ) = @_;

        if ( $args_ref->{image_dir} ) {
            $image_dir = $args_ref->{image_dir};
        }
        if ( $image_dir !~ m!/$! ) {
            $image_dir .= '/';
        }
        if ( !-d $image_dir ) {
            croak( 'Target image directory does not exist' );
        }

        croak('No source icon passed') if ( !$args_ref->{source} );

        if ( $args_ref->{source} !~ m!\.png$! ) {
            croak( 'Source image must be a PNG' );
        }

        if (   !-f $image_dir . $args_ref->{source}
            && !-f $args_ref->{source} )
        {
            croak( 'Source image does not exist' );
        }

        my $new_object = bless \do { my $anon_scalar }, $class;

        $source_of{ ident $new_object} = $args_ref->{source};
        ( $image_basename_of{ ident $new_object } ) =
          $args_ref->{source} =~ m!^(?:.*/)?(.*)\.png$!i;

        return $new_object;
    }

    sub get_image_basename {
        my ($self) = @_;
        return $image_basename_of{ ident $self};
    }

    sub get_image_full_basename {
        my ($self) = @_;
        return $image_dir . $image_basename_of{ ident $self};
    }

    sub get_source_image {
        my ($self) = @_;
        return $source_of{ ident $self};
    }

    sub _check_if_exists {
        my ( $self, $type ) = @_;
        croak('No file type provided') if ( !$type );
        if ( -f $self->get_image_full_basename . $type ) {
            return 1;
        }
        else {
            return 0;
        }
    }

    sub _check_prereqs {
        my ( $self, $source, $dest ) = @_;
        croak('No file source provided') if ( !$source );
        croak('No file dest provided')   if ( !$dest );
        if ( !$self->_check_if_exists($source) ) {
            croak( 'source doesnt exist - has it been converted?' );
        }

        if ( $self->_check_if_exists($dest) ) {
            return 1;
        }
        else {
            return 0;
        }
    }

    sub install_png {
        my ($self) = @_;

        if ( $self->_check_if_exists('.png') ) {
            return $self;
        }
        copy( $self->get_source_image, $self->get_image_full_basename . '.png'
        );
        return $self;
    }

    sub _convert {
        my ( $self, $source, $dest, $args ) = @_;
        $args ||= '';

        if ( $self->_check_prereqs( $source, $dest ) ) {
            return $self;
        }

        system( $bin_convert . ' '
              . $self->get_image_full_basename
              . $source . ' '
              . $args . ' '
              . $self->get_image_full_basename
              . $dest ) == 0
          || croak( 'Failed to convert ', $source, ' to ', $dest );
        return $self;
    }

    sub convert_to_small_png {
        my ($self) = @_;

        if ( $self->_check_prereqs( '.png', '_small.png' ) ) {
            return $self;
        }

        $self->_convert( '.png', '_small.png', '-resize 20x20' );
        return $self;
    }

    sub setup_all {
        my ($self) = @_;

        return $self->install_png->convert_to_small_png;
    }

    sub DESTROY {
        my ($self) = @_;

        delete $source_of{ ident $self} if ( $source_of{ ident $self} );
        delete $image_basename_of{ ident $self}
          if ( $image_basename_of{ ident $self} );
        return;
    }

}

1;

__END__

=head1 NAME

Utils::Hosticon - Helper module for installing Opsview icons

=head1 SYNOPSIS

  use Utils::Hosticon;
  $icon = Utils:Hosticon->new( { source => $path_to_source_png } );

  $name=$icon->get_image_basename;
  $path_and_name=$icon->get_full_image_basename;
  $source=$icon->get_source_image;

  $icon->install_gif;
  $icon->convert_to_pnm;
  $icon->convert_to_png;
  $icon->convert_to_gd2;
  $icon->convert_to_small_png;

  $icon->insatll_gif->convert_to_pnm->convert_to_png;

  $icon = Utils:Hosticon->new( { source => $path_to_source_gif } );
  $icon->setup_all;

=head1 DESCRIPTION

Module to help install Opsview icons to the correct directories.  No
database configuration is done - this purely works at the filelevel.

Images should be created in the order given above due to image source
dependancies.

When the module is first imported checks are done to ensure necessary 
binaries are available - ImageMagik is always used (binary: F<convert>),
netbpm and libgd-tools are used everywhere but Solaris.  If the binaries
are not available then the module will fail to load.

=head1 METHODS

=over 4

=item $icon = Utils::Hosticon->new( { source => $path_to_source_gif } )

Initialises an instance of Utils::Hosticon.  Source image should be a 
40x40 GIF image.  Croaks if the source file doesnt exist or is not named
with a C<.gif> suffix.  

The source image should be specified relative to the current 
directory (or absolute path given) but this is not necessary if the 
image is already in the correct directory.

=item $icon->install_gif

Takes the source image specified in the C<new> command and copies into
the appropriate image directory.  Returns the object.  Croaks if unable 
to copy.  Returns without copying if the image is already in place.

=item $icon->convert_to_xxxx

Converts the image to the specified type.  This must be done in a specific
order as some conversion rely on other having been done already.  See the
L</SYNOPSIS> for the correct order.  Will croak if a dependant image has not 
already been created.

Returns the object which allows the methods to be chained.

=item $icon->setup_all

Performs all the steps above in the correct order.

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut
