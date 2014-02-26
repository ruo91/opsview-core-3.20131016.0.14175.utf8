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

package Opsview::__::Contact;
use base qw(Opsview);

use strict;
our $VERSION = '$Revision: 2792 $';

__PACKAGE__->table( "contacts" );

__PACKAGE__->columns( Primary => qw/id/ );

# Optimised for lots of hits on UI
__PACKAGE__->columns( Essential => qw/name fullname role realm/ );
__PACKAGE__->columns(
    Others => qw/description
      encrypted_password
      language
      uncommitted/
);

package Opsview::Contact;
use strict;
use base qw(Opsview::__::Contact Opsview::Base::Contact);
use Opsview::Role::Constants;
use Crypt::PasswdMD5;
use Opsview::Config::Web;

__PACKAGE__->initial_columns(qw/name fullname/);

__PACKAGE__->has_a( role => "Opsview::Role" );

__PACKAGE__->default_search_attributes( { order_by => "name" } );

# Do not allow / in the username because we use that as a delimiter in nagconfgen
__PACKAGE__->constrain_column_regexp( fullname => '/^[\w .\/\+-]+$/', )
  ; # Legal characters
__PACKAGE__->constrain_column_regexp( name => '/^[\w.\@-]+$/', )
  ; # Legal characters

# ensure new contact is set to readonly role by default unless it is set
# explicitly
__PACKAGE__->add_trigger( before_create => \&fix_role );
__PACKAGE__->add_trigger( before_update => \&fix_role );

sub fix_role {
    my $self = shift;

    # Role = 1 is public, so no extra permissions set
    $self->role(1) unless $self->role();
}

# Make sure this user is not the authtkt_default_username
__PACKAGE__->add_trigger( before_delete => \&check_authtkt_default_username );

sub check_authtkt_default_username {
    my $self = shift;
    my $cfg  = Opsview::Config::Web->web_config;
    if (   $cfg->{authtkt_default_username}
        && $cfg->{authtkt_default_username} eq $self->name )
    {
        $self->_croak(
            "Cannot delete contact as used by authtkt_default_username"
        );
    }
}

# Below will be uncommented in a future version. Leave for now because of
# existing systems that may have mobile numbers in a different format
#__PACKAGE__->constrain_column(mobile => qr/^\+\d+$/);	# International format for mobile numbers

sub normalize_column_values {
    my ( $self, $h ) = @_;
    if ( exists $h->{encrypted_password} && $h->{encrypted_password} ) {
        $h->{encrypted_password} =
          apache_md5_crypt( $h->{encrypted_password} );
    }
}

=head1 NAME

Opsview::Contact - Accessing contact table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview contact information

=head1 METHODS

=over 4

=cut

sub fetchall {
    my $class = shift;
    my $dbh   = $class->db_Main;
    my $sth   = $dbh->prepare_cached( "SELECT * FROM contacts" );
    $sth->execute;
    return map { $class->construct($_) } $sth->fetchall_hash;
}

=item my_type_is

Returns "contact"

=cut

sub my_type_is {
    return "contact";
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
