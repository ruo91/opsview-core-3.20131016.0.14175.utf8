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

package Opsview::ResultSet::Hostgroups;

use strict;
use warnings;

use base qw/Opsview::ResultSet/;

# Ignore hosts, because don't know what we can default ones that get removed to
# Ignore children because only set via parents
sub synchronise_ignores {
    {
        hosts    => 1,
        children => 1
    };
}

sub synchronise_intxn_many_to_many_pre {
    my ( $self, $object, $attrs ) = @_;

    # Add parent. Use "parent" as the attribute name
    # This is required because the column is called "parentid", but the hash input is called "parent"
    # This requires $object->update to be called in Opsview::ResultSet::synchronise
    $object->parentid( delete $attrs->{parent} ) if exists $attrs->{parent};
}

# Note: The ordering is by matpath, which may fail if there are duplicate hostgroup names with the same parent
sub search_by_tree {
    my $self = shift;

    # The CONCAT trick was seen on MySQL site http://dev.mysql.com/doc/refman/5.0/en/string-functions.html
    # by Chris Stubben to count number of comma separators
    return $self->search(
        {},
        {
            "select" => [
                "id",
                \'CONCAT(REPEAT("-", (LENGTH(matpath)-LENGTH(REPLACE(matpath,",","")))-1), "> ", name)'
            ],
            "as"     => [qw/id name/],
            order_by => "matpath",
        }
    );
}

sub restricted_leaves_by_user {
    my ( $self, $user ) = @_;
    return $self->restrict_by_user($user)
      ->search( { rgt => \"= lft+1", }, { order_by => "name" } );
}

sub restrict_by_user {
    my ( $self, $user ) = @_;

    my @matpaths;

    for my $hg ( $user->role->hostgroups ) {

        # has top hostgroup
        return $self if $hg->id == 1;

        push @matpaths, $hg->matpath . '%';
    }

    return $self->search( { matpath => { "-like" => \@matpaths } } );
}

sub restricted_leaves_arrayref {
    my ($self) = @_;
    my @a = $self->restricted_leaves_by_user( $self->user );
    \@a;
}

sub restrict_status_objects_by_user {
    my ( $self, $user ) = @_;

    my $role = $user->role;
    if ( $role->all_hostgroups ) {
        my @hostgroups = $role->allowed_hostgroups();
        $self =
          $self->search( { id => { '-in' => [ map { $_->id } @hostgroups ] } }
          );
    }
    else {
        $self = $self->search(
            { "role_access_hostgroups.roleid" => $role->id },
            { join                            => "role_access_hostgroups" }
        );
    }

    return $self;

}

sub leaves {
    my ($self) = @_;
    return $self->search( { rgt => \"= lft+1" } );
}

sub non_leaf {
    my ($self) = @_;
    return $self->search( { rgt => \"!= lft+1" } );
}

sub order_by_depth_last {
    my ($self) = @_;
    return $self->search( {}, { order_by => "matpath" } );
}

sub search_leaves_without_hosts {
    my $self = shift;

    # The CONCAT trick was seen on MySQL site http://dev.mysql.com/doc/refman/5.0/en/string-functions.html
    # by Chris Stubben to count number of comma separators
    return $self->search(
        {},
        {
            join      => "hosts",
            '+select' => [ \"COUNT(hosts.id) AS hosts_count" ],
            "+as"     => ['hosts_count'],
            having    => { hosts_count => 0 },
            group_by  => "id",
        }
    );
}

# This is quite horrible. We need to do this so that when synchronisations occur, we search first by name
# then by matpath. DBIx::Class::ResultSet quite rightly doesn't do this because name is not a unique column
sub find {
    my ( $self, @args ) = @_;
    my $search = $args[0];
    if (   ref $search eq "HASH"
        && exists $search->{name}
        && exists $search->{matpath}
        && !exists $search->{id} )
    {
        return $self->find_by_name_matpath(
            "find",
            {
                name    => $search->{name},
                matpath => $search->{matpath}
            }
        );
    }
    else {
        return $self->next::method(@args);
    }
}

sub find_by_name_matpath {
    my ( $self, $action, $search, $info ) = @_;
    my @candidates = $self->search( { name => $search->{name} } );

    # Strip out host groups already seen, if this is a synchronise list request
    # Need to do this, otherwise with hostgroups that have duplicated names in the hierarchy, the wrong association will occur
    if ( ref($info) eq "HASH" && exists $info->{seen_ids} ) {
        @candidates = grep { !$info->{seen_ids}->{ $_->id } } @candidates;
    }

    my $count = scalar @candidates;
    if ( $count == 0 ) {
        if ( $action eq "find_or_new" ) {
            return $self->new( {} );
        }
        return undef;
    }
    elsif ( $count == 1 ) {
        return $candidates[0];
    }
    else {
        unless ( $search->{matpath} ) {
            if ( $action eq "find_or_new" ) {
                return $self->new( {} );
            }
            else {
                die "There is more than 1 host group with name "
                  . $search->{name}
                  . " and no matpath to distinguish";
            }
        }
        return $self->$action( { matpath => $search->{matpath} } );
    }
}

# We need to force the id attribute to exist when parent is undef - this is so that
# there is only ever one host group with parent=undef
sub synchronise {
    my ( $self, $original_attrs, $info ) = @_;

    my $get_highest_hostgroup_parent_res;
    if ( exists $original_attrs->{parent}
        && !defined $original_attrs->{parent} )
    {
        $original_attrs->{id} = 1;
    }
    elsif ($info->{create_only}
        && !exists $original_attrs->{parent}
        && $info->{user} )
    {

        # When creating a new host group and no parent is specified, we find the most appropriate
        # one and then after the host group is created, we add it to the access for this user's
        # role. This seems reasonable as the user created it
        $get_highest_hostgroup_parent_res =
          $info->{user}->get_highest_hostgroup_parent;

        unless ($get_highest_hostgroup_parent_res) {
            $info->{errors} = ["Cannot find suitable parent host group"];
        }
        else {
            $original_attrs->{parent} =
              $get_highest_hostgroup_parent_res->{hostgroup}->id;
        }
    }

    my $obj = $self->next::method( $original_attrs, $info );

    if (
        (
               $get_highest_hostgroup_parent_res
            or $original_attrs->{parent}
        )
        and $info->{user}
      )
    {
        my $role = $info->{user}->role;

        # Tick for this role
        unless ( $role->all_hostgroups ) {
            $role->add_to_access_hostgroups($obj);
        }

    }
    $info->{seen_ids}->{ $obj->id }++ if exists $info->{seen_ids};
    $obj;
}

sub synchronise_list_start {
    my ( $self, $options ) = @_;
    $options->{seen_ids} = {};
}

# When synchronising, the matpath field cannot be relied upon. So we use the
# host group name to find instead
sub synchronise_find {
    my ( $self, $action, $search_args, $attrs, $info ) = @_;

    # $search_args will be {} for host groups when going via synchronise
    if (%$search_args) {
        return $self->$action($search_args);
    }
    else {
        if ( $action eq "new" ) {
            return $self->new($attrs);
        }
        else {

            return $self->find_by_name_matpath(
                $action,
                {
                    name    => $attrs->{name},
                    matpath => $attrs->{matpath}
                },
                $info
            );
        }
    }
}

sub add_lft_rgt_values {
    my ($self) = @_;

    # Reset all matpath, so that unique constraint doesn't fail when calculating each individual matpath
    # (as could come across duplications while generating)
    $self->update( { matpath => undef } );

    sub rebuild_tree {
        my ( $object, $left, $materialized_path, $matpath_ids ) = @_;
        my $right = $left + 1;

        my $name = $object->name;
        if ($materialized_path) {
            $materialized_path .= ",$name";
            $matpath_ids .= "," . $object->id;
        }
        else {
            $materialized_path = "$name";
            $matpath_ids       = "1";
        }

        foreach my $child ( $object->children ) {
            $right =
              rebuild_tree( $child, $right, $materialized_path, $matpath_ids );
        }
        $object->update(
            {
                lft       => $left,
                rgt       => $right,
                matpath   => "$materialized_path,",
                matpathid => "$matpath_ids,",
            }
        );
        return $right + 1;
    }
    rebuild_tree( $self->find(1), 1, "" );
}

sub check_duplicate_leaf_name {
    my ( $self, $name, $my_id ) = @_;
    if ( $self->search_duplicate_leaf_name( $name, $my_id ) > 0 ) {
        $self->throw_exception(
            "Host group name $name has already been used for a leaf"
        );
    }
}

sub search_duplicate_leaf_name {
    my ( $self, $name, $my_id ) = @_;
    my $search_args = {
        name => $name,
        lft  => \"= rgt - 1",
    };
    if ($my_id) {
        $search_args->{id} = { "!=" => $my_id };
    }
    $self->search($search_args)->count;
}

sub check_name_clash_with_same_parent {
    my ( $self, $object, $newname ) = @_;
    my $parentid = $object->parentid;
    if ( ref $parentid ) { $parentid = $parentid->id }
    foreach my $hg ( $self->search( { parentid => $parentid } ) ) {
        next if ( $object->id && $object->id == $hg->id );
        if ( $hg->name eq $newname ) {
            $self->throw_exception(
                "Same host group name '$newname' used with same parent - this is invalid"
            );
        }
    }
}

1;
