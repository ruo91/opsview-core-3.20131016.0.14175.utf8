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

package Opsview::ResultSet;

use strict;
use warnings;

use base qw/DBIx::Class::ResultSet/;
use Opsview::Auditlog;
use Opsview::Utils qw(convert_to_arrayref convert_perl_regexp_to_js_string);
use Try::Tiny;
use Data::Dump;
use JSON;

# Want indent so audit logs page shows it nicely
# Want canonical to force same ordering on web page every time
my $json = JSON->new->indent(1)->canonical(1);

# Force use of delete_all (to get triggers)
sub delete { shift->delete_all(@_) }

sub retrieve_all          { shift->search }
sub retrieve_all_arrayref { shift->search }

# Set validation regexps. Defined in Opsview::Schema::*::add_columns
# This puts it in the style that TT expects it
__PACKAGE__->mk_classdata( "validation_regexp_cached" );
__PACKAGE__->mk_group_accessors( simple => qw/user/ );
__PACKAGE__->mk_group_accessors( simple => qw/_error_relation/ );

sub validation_regexp {
    my $self = shift;
    if ( $self->validation_regexp_cached ) {
        return $self->validation_regexp_cached;
    }
    my $h = {};
    foreach my $c ( $self->result_source->columns ) {
        if ( my $constrain =
            $self->result_source->column_info($c)->{constrain_regex} )
        {
            $h->{$c} = "/" . $constrain->{regex} . "/";
            my $err = "${c}_error";
            $h->{$err} = $constrain->{error_message};
        }
    }

    # Merge with dfv_profile
    my $schema_class = $self->result_class;
    if ( $schema_class->can("get_dfv_profile") ) {
        my $dfv_profile = $schema_class->get_dfv_profile;
        if ( exists $dfv_profile->{constraint_methods} ) {
            foreach my $k ( keys %{ $dfv_profile->{constraint_methods} } ) {
                $h->{$k} = convert_perl_regexp_to_js_string(
                    $dfv_profile->{constraint_methods}->{$k}
                );
            }
        }
    }
    return $self->validation_regexp_cached($h);
}

sub throw_error {
    my ( $class, $error ) = @_;
    chomp($error);
    die "$error\n";
}

# Get the foreign object and error if doesn't exist
sub expand_foreign_object {
    my ( $self, $args ) = @_;
    my $rel = $args->{rel} || "";
    my $rs = $args->{rs}
      || $self->result_source->related_source($rel)->resultset;
    my $search = $args->{search};
    my $errors = $args->{errors} || [];

    # Return object if already one
    my $reftype = ref $search;
    if ( $reftype ne '' && $reftype ne 'HASH' ) {
        return $search;
    }

    my $foreign_method = "find";
    if ( exists $self->auto_create_foreign->{$rel} ) {

        # Set the relation in case an error is thrown
        $self->_error_relation($rel);
        $foreign_method = "find_or_create";
    }
    my $fobj;

    # Need to have this eval because could get exceptions if database errors
    # Don't include $errors, as there could be other checks to run later
    try { $fobj = $rs->$foreign_method($search) }
    catch { $self->throw_if_error($_) };

    # Reset for next call
    $self->_error_relation( "" );

    unless ($fobj) {
        my $info = $search;
        if ( ref $search eq "HASH" ) {
            $info = join( ",",
                map { ( defined $_ ? $_ : "" ) . "=" . $search->{$_} }
                  ( keys %$search )
            );
        }
        push @$errors, "No related object for $rel '$info'";
        return undef;
    }
    $fobj->{_stash}->{original_attrs} = $search;
    return $fobj;
}

sub relationships_to_expand {
    my $self = shift;
    my %rels;
    my $relinfo = $self->result_class->relationships_to_related_class;
    foreach my $rel ( keys %$relinfo ) {
        $rels{$rel} = 1 if $relinfo->{$rel}->{type} eq "single";
    }
    return \%rels;
}

sub relationships_many {
    my $self = shift;
    my %rels;
    my $relinfo = $self->result_class->relationships_to_related_class;
    foreach my $rel ( keys %$relinfo ) {
        $rels{$rel} = $relinfo->{$rel}->{class}
          if $relinfo->{$rel}->{type} eq "multi";
    }
    return \%rels;
}

sub relationships_might_have {
    my $self = shift;
    my %rels;
    my $relinfo = $self->result_class->relationships_to_related_class;
    foreach my $rel ( keys %$relinfo ) {
        $rels{$rel} = 1 if $relinfo->{$rel}->{type} eq "might_have";
    }
    return \%rels;
}

sub relationships_has_many {
    my $self = shift;
    my %rels;
    my $relinfo = $self->result_class->relationships_to_related_class;
    foreach my $rel ( keys %$relinfo ) {
        $rels{$rel} = 1 if $relinfo->{$rel}->{type} eq "has_many";
    }
    return \%rels;
}

# Bear in mind that access control states that you shouldn't be able to just add new objects
# automatically, so it may need to be done at the Opsview Web level instead
sub auto_create_foreign { {} }

sub synchronise_ignores { {} }

sub synchronise_allowed_duplicates { {} }

sub synchronise_pre_txn {
    my ( $self, $attrs, $errors ) = @_;
}

sub synchronise_intxn_object_found {
    my ( $self, $object, $attrs, $errors ) = @_;
}

sub synchronise_intxn_pre_insert {
    my ( $self, $object, $attrs, $errors ) = @_;
}

sub synchronise_intxn_post {
    my ( $self, $object, $attrs, $errors ) = @_;
}

sub synchronise_intxn_many_to_many_pre {
    my ( $self, $object, $attrs ) = @_;
}

sub synchronise_amend_audit_attrs {
    my ( $self, $object, $attrs ) = @_;
}

sub synchronise_list_start {
    my ( $self, $options ) = @_;
}

sub synchronise_list_end {
    my ( $self, $options ) = @_;
}

# Expects a hash of all the data. Will then make all the changes to the database
# See t/945hosts.t for structure of input
# Will throw exception if any errors
sub synchronise {
    my ( $self, $original_attrs, $info ) = @_;
    $info ||= {};

    # Take a copy of attributes as txn may change it
    my $attrs = {%$original_attrs};
    $attrs->{".level"} = 0 unless exists $attrs->{".level"};

    # Delete any ref attributes as this is only meta data
    $attrs =
      Opsview::Utils->remove_keys_from_hash( $attrs, ["ref"],
        "do_not_die_on_non_hash" );

    my @errors = @{ $info->{errors} || [] };
    my $username = $info->{username} || "";

    my $type = $self->class_title;
    my $ident;
    my $search_args = {};
    my $id          = delete $attrs->{id};
    if ($id) {
        $search_args = { id => $id };
        $ident = "id=$id";
    }
    else {

        # Setup search based on unique constraints
        my %unique_constraints = ( $self->result_source->unique_constraints );
        foreach my $key ( keys %unique_constraints ) {
            my @ident;
            foreach my $k ( @{ $unique_constraints{$key} } ) {
                if ( exists $attrs->{$k} ) {
                    $search_args->{$k} = $attrs->{$k};
                    push @ident, "$k=" . $attrs->{$k};
                }
            }
            $ident = join( ", ", @ident );
        }
    }

    # For has_many foreign objects, set to the other object
    my $relationships_to_expand = $self->relationships_to_expand;
    foreach my $rel ( keys %$relationships_to_expand ) {
        my $search = $attrs->{$rel};

        # If an array is passed instead of a single element, use the first
        if ( ref $search eq "ARRAY" ) {
            $search = $search->[0];
        }
        next unless defined $search;
        if ( $search eq '' ) {
            $attrs->{$rel} = undef;
            next;
        }
        $attrs->{$rel} = $self->expand_foreign_object(
            {
                rel    => $rel,
                search => $search,
                errors => \@errors
            }
        );
    }

    my $ignores = $self->synchronise_ignores;
    delete $attrs->{$_} for keys %$ignores;

    # For many_to_many foreign objects, find them
    my $relationships_many = $self->relationships_many;
    foreach my $rel ( keys %$relationships_many ) {
        my $search = $attrs->{$rel};
        next unless defined $search;
        if ( ref $search eq '' ) {
            $search = [$search];
        }
        if ( ref $search eq "ARRAY" ) {
            my @result = map {
                $self->expand_foreign_object(
                    {
                        rel => $rel,
                        rs  => $self->result_source->schema->resultset(
                            $relationships_many->{$rel}
                        ),
                        search => $_,
                        errors => \@errors
                    }
                  )
            } @$search;
            $attrs->{$rel} = \@result;
        }
    }

    # Remove duplicates from many_to_many foreign objects
    my $allowed_duplicates = $self->synchronise_allowed_duplicates;
    foreach my $rel ( keys %$relationships_many ) {
        next unless $attrs->{$rel};
        next if $allowed_duplicates->{$rel};
        my %seen;
        my @new = ();
        $self->throw_error("Field '$rel' is not an array")
          unless ( ref $attrs->{$rel} eq "ARRAY" );
        foreach my $obj ( @{ $attrs->{$rel} } ) {
            next unless defined $obj; # Could be undef if object not resolveable
            next if $seen{ $obj->id }++;
            push @new, $obj;
        }
        $attrs->{$rel} = \@new;
    }

    try { $self->synchronise_pre_txn( $attrs, \@errors ) }
    catch { $self->throw_if_error( $_, \@errors ) };

    my $object;

    my $relationships_might_have = $self->relationships_might_have;
    my $relationships_has_many   = $self->relationships_has_many;

    # This crazy jumping around is required because of
    # Data::FormValidator::Results overriding boolean with the status of the validation
    # Maybe DBIx::Class::Validator should encapsulate Data::FormValidator::Results and stop the boolean mess
    my $action = sub {

        my $action = "find_or_new";
        if ( $info->{create_only} ) {
            $action = "new";
        }
        $object =
          $self->synchronise_find( $action, $search_args, $attrs, $info );

        $self->synchronise_intxn_object_found( $object, $attrs, \@errors );

        # Set attributes
        foreach my $attr ( keys %$attrs ) {
            next if $attr =~ /^\./;
            if ( $object->has_column($attr) ) {
                $object->$attr( $attrs->{$attr} );
            }
        }

        $object->uncommitted(1) if $object->has_column( "uncommitted" );

        if ( $object->in_storage ) {
            $object->update;
        }
        else {
            $self->synchronise_intxn_pre_insert( $object, $attrs, \@errors );
            $object->insert;
        }

        $self->synchronise_intxn_many_to_many_pre( $object, $attrs );

        # Add might_have relationships. This must come after initial object, because otherwise object gets inserted before all attributes set
        foreach my $attr ( keys %$attrs ) {
            if ( exists $relationships_might_have->{$attr} ) {
                $object->$attr( $attrs->{$attr} );
            }
        }

        # Add many_to_many
        foreach my $rel ( keys %$relationships_many ) {

            my $objs = $attrs->{$rel};
            next unless $objs;

            # Allow overriding at model
            $_ = "synchronise_override_$rel";
            if ( $self->can($_) ) {
                $self->$_( $object, $objs, \@errors );
            }
            else {
                $_ = "set_$rel";
                $object->$_($objs);
            }
        }

        # Recursively synchronise has_many relationships
        foreach my $rel ( keys %$relationships_has_many ) {
            if ( my $hashes = $attrs->{$rel} ) {
                my @updated_ids;

                # Make a call to a private function. Need to get the reverse condition to then add to the hash
                my $cond =
                  $object->result_source->_resolve_condition(
                    $object->relationship_info($rel)->{cond},
                    $rel, $object, );

                my $priority = 1;
                $hashes = convert_to_arrayref($hashes);
                foreach my $hash (@$hashes) {
                    my $item = $object->related_resultset($rel)->synchronise(
                        {
                            priority => $priority,
                            %$hash, %$cond, ".level" => $attrs->{".level"} + 1
                        }
                    );
                    push @updated_ids, $item->id;
                    $priority++;
                }
                $object->$rel->search( { id => { -not_in => \@updated_ids } } )
                  ->delete_all;
            }
        }

        $self->synchronise_intxn_post( $object, $attrs, \@errors );
        $self->throw_if_error( undef, \@errors );

        # Need this to force any changes that may have been made in the synchronise override routines (see Hostgroups)
        $object->update;

        # Need to do this to force re-reading of object from database
        $object->discard_changes;
    };

    try {
        $self->result_source->schema->txn_do($action);
    }
    catch {
        $self->throw_if_error( $_, \@errors );
    };

    if ( !defined $ident ) {
        $ident = "id=" . $object->id;
    }

    if ( $attrs->{".level"} == 0 ) {
        $self->synchronise_amend_audit_attrs( $object, $original_attrs );
        Opsview::Auditlog->create(
            {
                username => $username,
                text     => "Synchronised $type $ident: "
                  . $json->encode($original_attrs)
            }
        );
    }
    $object;
}

# Make this override-able. Specifically for Hostgroups.pm as we need to override
sub synchronise_find {
    my ( $self, $action, $search_args, $attrs, $info ) = @_;
    return $self->$action($search_args);
}

sub throw_if_error {
    my ( $self, $exception, $errors ) = @_;
    $errors ||= [];
    if (@$errors) {
        $self->throw_error( join( "; ", @$errors ) );
    }
    if ( defined $exception ) {
        my $error_relation = $self->_error_relation || "";
        $self->_error_relation( "" );

        #if ( $exception->isa("DBIx::Class::Validation::Exception") ) {
        if ( $exception->isa("Data::FormValidator::Results") ) {
            my @errors;
            my $errors = $exception->msgs;
            foreach my $a ( keys %$errors ) {
                push @errors, "$a: " . $errors->{$a};
            }

            my $text = join( "; ", @errors );
            $text = $error_relation . ": " . $text if $error_relation;
            $self->throw_error($text);
        }
        elsif ( $exception->isa("DBIx::Class::Exception") ) {
            $self->throw_error( "$exception" );
        }
        die $exception;
    }
}

sub synchronise_handle_variables {
    my ( $self, $object, $attrs ) = @_;
    if ( defined $attrs->{variables} ) {
        my $vars = convert_to_arrayref( $attrs->{variables} );
        foreach my $hash (@$vars) {
            my $name  = $hash->{name};
            my $value = $hash->{value};
            if ( defined $name && defined $value ) {
                $object->set_variable( $name, $value );
            }
        }
    }
}

sub class_title {
    my ($self) = @_;
    my $class_string = ref $self;
    $class_string =~ s/.*:://g;
    $class_string = lc($class_string);
    $class_string;
}

sub my_type_is {
    my ($self) = @_;
    $self->result_class->my_type_is;
}

# This is required so that unique checks can find out if columns are in the result to search
sub has_column { shift->result_class->has_column(@_) }

# This should be overridden by the subclass to apply
# restrictions based on the user object. This gives an error
# if that doesn't happen
sub restrict_by_user {
    die
      "Non-subclassed restrict_by_user method called - this shouldn't have happened";
}

1;
