#
#
# DESCRIPTION:
# 	This is a base class for the Opsview::CRUD::* set of modules
# 	The idea is that this is a CRUD interface between the API and Web controllers
# 	and the Opsview::* models.
# 	All data structures passed here are in hash form. The underlying modules
# 	will convert to the required DB information (including foreign classes)
# 	while the higher level ones don't really care what the relationships are
# 	There are four supported class methods:
# 	  * create / put
# 	  * retrieve / get
# 	  * update / post
# 	  * delete / delete
#	Each will return the relevant Opsview::* object after the processing (except delete)
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

package Opsview::CRUD::Base;
use warnings;
use strict;
use Carp;
use Utils::ContextSave;

use base qw(Utils::ContextSave);

=head1 NAME

Opsview::CRUD::Base - CRUD type interaction with Opsview::* objects

=head1 DESCRIPTION

Handles the common Create/Retrieve/Update/Delete methods, using hashes as the data format

=head1 METHODS

=over 4

=item __PACKAGE__->do_create( $hash )

Takes a data hash, provided via API or (not supported yet) from web parameters and does 
all the necessary processing to add to database.

=item __PACKAGE__->do_retrieve( $primary_key )

Gets specified object and returns

=item $self->do_update( $hash )

Updates object with hash data

=item $self->do_delete

Deletes object as a transaction

=cut

# Essentially do_create_new from opsview-web/lib/Opsview/Web/ControllerBase/Admin.pm
sub do_create {
    my ( $class, $hash ) = @_;
    my $audit_fields = [];
    my $audit_title  = "";
    my $o;

    local $class->db_Main->{AutoCommit}; # Turn off autocommit for block

    eval {
        if ( $hash->{clone} )
        {
            my ($key) = keys %{ $hash->{clone} };
            my $search_by = { $key => $hash->{clone}->{$key} };
            my $cloned_from = $class->search($search_by)->first;
            $class->_croak(
                sprintf(
                    "Object %s='%s' not found",
                    $key, $hash->{clone}->{$key}
                )
            ) unless $cloned_from;
            $class->_merge_with_clone( $hash, $cloned_from->as_hash );
            delete $hash->{clone};
            $audit_title =
                "Cloning "
              . $class->class_title
              . " from "
              . $cloned_from->identity_string . ": ";
        }
        else {
            $audit_title = "Creating " . $class->class_title . ": ";
        }

        $class->_normalize_foreign_objects($hash);

        my %init;
        foreach my $col ( @{ $class->initial_columns } ) {
            unless ( exists $init{$col} ) {
                $init{$col} = $hash->{$col}
                  || $class->_croak( sprintf( "Field %s is mandatory", $col )
                  );
                push @$audit_fields, "$col='" . $hash->{$col} . "'";
            }
            delete $hash->{$col};
        }

        eval { $o = $class->create( \%init ) };
        $class->_croak($@) if ($@);
        $audit_fields = $o->do_update( $hash, $audit_fields );
    };
    if ($@) {
        warn( "create error: $@" );
        my $commit_error = $@;
        eval { $class->dbi_rollback };
        $class->_croak($commit_error);
    }

    $o->uncommitted(1) if $o->can( 'uncommitted' );
    $o->update;

    # Problem here in future when API extended to do updates
    # I think this should be moved into a controller in future:
    #   /api/host can be a private method so you can pass the object in the stash
    # O::W::C::Api seems to be a dispatcher, but that's Catalyst's strength
    # Still like the idea that a hash describes the changes, but need to get it aligned with
    # the web posting mechanism
    # USERNAME_BLANK: Added || "" because username cannot be null - this should always be set when going through web API
    # However, fails tests in t/600objects.t. As this code is going to be deprecated within the year, this is fine to do
    Opsview::Auditlog->create(
        {
            username => $o->username || "",
            text => $audit_title . join( ", ", @$audit_fields ),
        }
    );

    return $o;
}

sub _merge_with_clone {
    my ( $self, $h, $cloned_from ) = @_;
    my %ignores = map { ( $_ => 1 ) } ( @{ $self->ignore_clone_fields } );
    foreach my $key ( keys %$cloned_from ) {
        next if $ignores{$key};
        if ( !exists $h->{$key} ) {
            $h->{$key} = $cloned_from->{$key};
        }
    }
}

# Essentially do_update from opsview-web/lib/Opsview/Web/ControllerBase/Admin.pm
sub do_update {
    my ( $self, $values, $audit_fields ) = @_;
    $audit_fields ||= [];

    PARAM: foreach my $p ( keys %$values ) {
        my $val = $values->{$p};
        if ( !defined $val ) {

            #warn("Setting ${p} to undef");
            $self->$p(undef);
            push @$audit_fields, "$p=undef";
        }
        elsif ( ref $val eq "" ) {

            #warn("Setting ${p} to '$val'");
            $self->$p($val);
            push @$audit_fields, "$p='$val'";
        }
        elsif ( ref $val eq "ARRAY" ) {
            if (@$val) {

                #warn("Setting ${p} to ".join(",", @$val));
            }
            else {

                #warn("Setting ${p} to empty list");
            }
            my $meth = "set_${p}_to";
            $self->$meth(@$val);
            push @$audit_fields, "$p=(" . join( ",", @$val ) . ")";
        }
        else {
            if ( $self->can($p) ) {
                $self->$p($val);
                push @$audit_fields, "$p='$val'";
            }
            else {
                $self->_croak( "Wierd stuff happening here" );
            }
        }
    }
    return $audit_fields;
}

# Makes foreign attributes use their primary key
# instead of the hash, eg becomes check_command => 1, instead
# of check_command => { id => 1 }
sub _normalize_foreign_objects {
    my ( $class, $hash ) = @_;
    my $foreign = $class->foreign_keys;
    foreach my $key ( keys %$hash ) {
        my $v = $hash->{$key};
        if ( $v && ref($v) eq "HASH" ) {
            if ( exists $v->{id} ) {
                $_ = $foreign->{$key}->retrieve( $v->{id} );
                unless ($_) {
                    return $class->_croak(
                        sprintf(
                            "Cannot find object %s with id=%s",
                            $key, $v->{id}
                        )
                    );
                }
                $hash->{$key} = $_;
            }
            else {
                $_ = $foreign->{$key}->search( name => $v->{name} );
                unless ($_) {
                    $class->_croak(
                        sprintf(
                            "Cannot find object %s with name '%s'",
                            $key, $v->{name}
                        )
                    );
                }
                $hash->{$key} = $_->first;
            }
        }
        elsif ( $v && ref($v) eq "ARRAY" ) {
            my @a;
            foreach my $i (@$v) {

                # TODO: Need to ignore if already an object
                if ( exists $i->{id} ) {
                    $_ = $foreign->{$key}->retrieve( $i->{id} );
                    unless ($_) {
                        return $class->_croak(
                            sprintf(
                                "Cannot find object %s with id=%s",
                                $key, $i->{id}
                            )
                        );
                    }
                    push @a, $_;
                }
                else {
                    $_ = $foreign->{$key}->search( name => $i->{name} );
                    unless ($_) {
                        return $class->_croak(
                            sprintf(
                                "Cannot find object %s with name '%s'",
                                $key, $i->{name}
                            )
                        );
                    }
                    push @a, $_->first;
                }
            }
            $hash->{$key} = \@a;
        }
    }
}

sub do_retrieve { shift->retrieve(@_) }

sub do_delete {
    my $self = shift;
    local $self->db_Main->{AutoCommit}; # Turn off autocommit for block

    # See USERNAME_BLANK for reasons for "" below
    my $info = {
        username => $self->username || "",
        text => "Deleted " . $self->class_title . ": " . $self->identity_string
    };
    eval { $self->delete(@_) };
    if ($@) {
        warn( "delete error: $@" );
        my $commit_error = $@;
        eval { $self->dbi_rollback };
        $self->_croak($commit_error);
    }
    $self->_croak($@) if $@;
    Opsview::Auditlog->create($info);
}

sub _croak {
    my ( $ref, $msg ) = @_;
    croak($msg);
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
