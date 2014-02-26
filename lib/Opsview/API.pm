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

package Opsview::API;

use warnings;
use strict;
use Carp;
use WWW::Mechanize;
use Opsview::Utils qw(apidatatidy);
our $VERSION = '0.5';

=head1 NAME

Opsview::API - Accessing Opsview's API2

=head1 SYNOPSIS

  use Opsview::API;
  my $ov = Opsview::API->new(
    username => "admin",
    password => "initial",
    url_prefix => "https://opsview.example.com/ov",
  );

=head1 DESCRIPTION

This module interacts with the Opsview API2 so you can retrieve configuration information,
make changes to objects and delete objects.

This is a perl way to access Opsview's webservice.

=head1 CONSTRUCTOR

=over 4

=item new

Takes the required parameters of username, password and url_prefix.

Can specify dataformat. Defaults to perl

Will automatically login when required.

Errors will be propagated with a croak and the error message can be 
retrieved with $self->error

=back

=cut

sub new {
    my ( $class, %params ) = @_;
    croak "Must specify username"        unless $params{username};
    croak "Must specify password"        unless $params{password};
    croak "Must specify url_prefix"      unless $params{url_prefix};
    croak "Must specify api_min_version" unless $params{api_min_version};

    my %defaults = ( pretty => 0, );
    my $self = { %defaults, %params };

    my $input = $self->{data_format} || "perl";
    my $input_mappings = {
        perl => "text/x-data-dumper",
        yml  => "text/x-yaml",
        yaml => "text/x-yaml",
        json => "application/json",
        xml  => "text/xml",
    };
    my $content_type = $input_mappings->{$input}
      || croak(
        "Unknown type $input. Possible types: "
          . join( ", ", sort keys %$input_mappings )
      );

    $self->{content_type} = $content_type;
    $self->{url_prefix} =~ s/\/$//; # Remove trailing / if present
    $self->{url_prefix} .= "/rest";

    # Force no storage of cookies
    my $mech = WWW::Mechanize->new(
        autocheck   => 1,
        onerror     => sub { $self->throw(@_) },
        stack_depth => 0,
        cookie_jar  => undef
    );
    $self->{_mech} = $mech;

    # Need to set this header to stop Apache from returning a gzip'd response. I think there is a bug in WWW::Mechanize
    # where it is not uncompressing the result properly when a request is for json but response is in HTML
    $mech->add_header( "Accept-Encoding" => "identity" );
    $mech->add_header( 'Content-Type'    => $content_type );
    $mech->add_header( 'Accept'          => $content_type );

    $self->{_logged_in} = 0;
    $self->{error}      = "";
    bless $self, $class;
}

sub throw {
    my ( $self, @args ) = @_;
    $self->{error} = join( "", @args );
    if ( length $self->content ) {
        print $self->content . $/;
    }
    croak $self->{error};
}

=head1 METHODS

=over 4

=item login

Logs into Opsview

=cut

sub login {
    my $self = shift;
    return if $self->{_logged_in};

    my $data;
    my $mech = $self->mech;

    # Force login in perl format
    $mech->add_header( 'Content-Type' => 'text/x-data-dumper' );
    $mech->add_header( 'Accept'       => 'text/x-data-dumper' );

    # Check API version
    $mech->get( $self->{url_prefix} );

    $data = eval $mech->content;
    if ( $self->{api_min_version} < $data->{api_min_version} ) {
        $self->throw(
                "Client API version "
              . $self->{api_min_version}
              . " is too low. API version at "
              . $data->{api_min_version}
        );
    }

    # Login
    $mech->post(
        $self->{url_prefix} . "/login",
        Content => '{ username => "'
          . $self->{username}
          . '", password => "'
          . $self->{password} . '" }'
    );
    $data = eval $mech->content;
    if ( !$data->{token} ) {
        $self->throw( "No token found" );
    }
    $self->{_mech}->add_header( "X-Opsview-Username", $self->{username} );
    $self->{_mech}->add_header( "X-Opsview-Token",    $data->{token} );

    # Set requested Content-type for subsequent conversations
    $self->mech->add_header( "Content-Type" => $self->{content_type} );
    $self->mech->add_header( "Accept"       => $self->{content_type} );
    $self->{_logged_in} = 1;
}

sub mech { shift->{_mech} }

sub is_success {
    my $self = shift;
    $self->{_error} ? 0 : 1;
}

sub absolute_path {
    my ( $self, $path ) = @_;
    if ( $path =~ m%^/% ) {
        return $path;
    }
    return $self->{url_prefix} . "/" . $path;
}

sub post {
    my ( $self, $path, $data ) = @_;
    $self->mech->post( $self->absolute_path($path), Content => $data );
    $self;
}

sub get {
    my ( $self, $path ) = @_;
    $self->mech->get( $self->absolute_path($path) );
    $self;
}

sub put {
    my ( $self, $path, $data ) = @_;
    $self->mech->put( $self->absolute_path($path), Content => $data );
    $self;
}

sub delete {
    my ( $self, $path ) = @_;
    my $req = HTTP::Request->new( "DELETE" => $self->absolute_path($path) );
    $self->mech->request($req);
    $self;
}

sub content {
    my ($self) = @_;
    my $content = $self->mech->response->content;
    if ( $self->{pretty} ) {
        return apidatatidy($content);
    }
    return $content;
}

=item error

Returns the error message

=cut

sub error { shift->{_error} }

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=head1 SEE ALSO

http://www.opsview.org/

http://docs.opsview.com/doku.php?id=opsview-core:api

=cut

1;
