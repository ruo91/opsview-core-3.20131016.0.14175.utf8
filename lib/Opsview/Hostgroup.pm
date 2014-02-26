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

package Opsview::Hostgroup;
use base 'Opsview';

use strict;
our $VERSION = '$Revision: 2849 $';

__PACKAGE__->table( "hostgroups" );

__PACKAGE__->columns( Primary   => qw/id/ );
__PACKAGE__->columns( Essential => qw/name parentid matpath uncommitted/ );

# Ignore the lft and rgt columns as these shouldn't be accessed
# Is a staging area for runtime's copy of this table

__PACKAGE__->columns( Stringify => qw/name/ );

__PACKAGE__->utf8_columns( qw(name) );

__PACKAGE__->has_a( parentid => 'Opsview::Hostgroup' );

__PACKAGE__->might_have(
    info => "Opsview::Hostgroupinfo" => qw/ information / );

__PACKAGE__->has_many(
    hosts => "Opsview::Host",
    { cascade => 'Fail' }
);
__PACKAGE__->has_many(
    keywords => [ "Opsview::KeywordHostgroup" => "keywordid" ],
    "hostgroupid"
);

__PACKAGE__->default_search_attributes( { order_by => "name" } );

# Must constrain "," as this is used as the separator for the material path
# We chose comma, because period and forward slash already allowed, and comma is high up the ascii order
# so that UK,sublevel is above UK2,sublevel (which is not the case if, say, colon was used instead)
__PACKAGE__->constrain_column_regexp( name => q{/^[\w .\/\+-]+$/} =>
      "invalidCharactersOnlyAlphanumericsOrSpaceDashPeriodSlashPlus" );
__PACKAGE__->initial_columns( "name" );

# Override retrieve_all so that it pulls the list of leaves
sub retrieve_all {
    my $class = shift;
    $class->search_leaves;
}

# This returns a list of leaves, ie, hostgroups at the bottom of the hierarchical tree
__PACKAGE__->set_sql( leaves => <<"" );
SELECT __ESSENTIAL(me)__
FROM __TABLE__ me
LEFT JOIN __TABLE__ h2
ON (me.id = h2.parentid)
WHERE h2.id IS NULL
AND me.id != 1
ORDER BY me.name

__PACKAGE__->set_sql( find_leaves => <<"" );
SELECT __ESSENTIAL(me)__
FROM %s
LEFT JOIN __TABLE__ h2
ON (me.id=h2.parentid)
WHERE h2.id IS NULL AND %s
AND me.id != 1
GROUP BY __ESSENTIAL(me)__
%s
%s

__PACKAGE__->set_sql( duplicate_leaf_name => <<"" );
SELECT COUNT(*)
FROM __TABLE__ h
LEFT JOIN __TABLE__ h2
ON (h.id = h2.parentid)
WHERE h2.id IS NULL
AND h.name = ?

__PACKAGE__->set_sql( duplicate_leaf_name_except_myself => <<"" );
SELECT COUNT(*)
FROM __TABLE__ h
LEFT JOIN __TABLE__ h2
ON (h.id = h2.parentid)
WHERE h2.id IS NULL
AND h.name = ?
AND h.id != ?

__PACKAGE__->add_trigger( before_delete => \&inherit_children );

sub inherit_children {
    my $self = shift;
    return 0 if ( $self->id == 1 ); # Ignore if top of tree and stop delete
    my $parent = $self->parentid;
    foreach my $c ( $self->children ) {
        $c->parentid($parent);
        $c->update;
    }
}

__PACKAGE__->add_trigger( before_create => \&check_name_set );
__PACKAGE__->add_trigger(
    before_create => \&check_name_clash_with_other_leaves );
__PACKAGE__->add_trigger(
    before_create => \&check_name_clash_with_same_parent );

sub check_name_set {
    my $self = shift;
    unless ( $self->{name} ) {
        $self->_croak( "Must specify a name to create a new hostgroup" );
    }
}

sub check_name_clash_with_other_leaves {
    my $self = shift;

    # try to detect if object has been created or is changed
    if ( ( $self->can("uncommitted") || $self->is_changed )
        && $self->sql_duplicate_leaf_name->select_val( $self->{name} ) )
    {
        $self->_croak(
                "Hostgroup name "
              . $self->name
              . " has already been used for a leaf"
        );
    }
}

sub check_name_clash_with_same_parent {
    my $self     = shift;
    my $parentid = $self->parentid;
    if ( ref $parentid ) { $parentid = $parentid->id }
    foreach my $hg ( $self->search( parentid => $parentid ) ) {
        next if ( $self->{id} && $hg->id == $self->{id} );
        if ( $hg->name eq $self->name ) {
            $self->_croak( "system.messages.hostgroup.samenamesameparentclash"
            );
        }
    }
}

sub check_name_clash_with_other_leaves_update {
    my $self = shift;
    if ( exists $self->{__Changed}->{name} ) {
        if (
            $self->sql_duplicate_leaf_name_except_myself->select_val(
                $self->{name}, $self->id
            )
          )
        {
            $self->_croak(
                    "Hostgroup name "
                  . $self->{name}
                  . " has already been used for a leaf"
            );
        }
    }
}

__PACKAGE__->add_trigger(
    before_update => \&check_name_clash_with_other_leaves_update );
__PACKAGE__->add_trigger( before_update => \&check_circular_parentid );
__PACKAGE__->add_trigger(
    before_update => \&check_name_clash_with_same_parent );

sub check_circular_parentid {
    my $self = shift;
    if ( $self->parentid && $self->id == $self->parentid->id ) {
        if ( $self->{id} == 1 ) {
            $self->{parentid} = undef;
        }
        else {
            $self->{parentid} = 1;
        }
    }
}

# Update matpath column
__PACKAGE__->add_trigger( after_create => \&trigger_add_lft_rgt_values );
__PACKAGE__->add_trigger( after_update => \&trigger_add_lft_rgt_values );
__PACKAGE__->add_trigger( after_delete => \&trigger_add_lft_rgt_values );

sub trigger_add_lft_rgt_values { __PACKAGE__->add_lft_rgt_values }

=head1 NAME

Opsview::Hostgroup - Accessing hostgroups table

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

Handles interaction with database for Opsview hostgroup information

=head1 METHODS

=over 4

=item Opsview::Hostgroup->promote_hostgroups($dbname, $tablename)

Takes opsview.hostgroups table and copies it to $dbname.$tablename. The runtime db is used to draw the hostgroup hierarchy views 

=cut

sub promote_hostgroups {
    my ( $class, $dbname, $tablename ) = @_;
    my $dbh = Opsview->db_Main;
    ( my $opsview_db ) = $dbh->{Name} =~ m/database=(\w+)/;
    $tablename = $tablename || "hostgroups";
    $dbh->do( "TRUNCATE $dbname.$tablename" );
    $dbh->do(
        "INSERT INTO $dbname.$tablename SELECT id, parentid, name, NULL, NULL, '' FROM $opsview_db.hostgroups"
    );

    $class->add_lft_rgt_values( $dbname, $tablename );
}

=item Opsview::Hostgroup->add_lft_rgt_values($dbname, $tablename)

Adds the lft and rgt values to the hostgroup information.
Takes opsview.hostgroups table and copies it to $dbname.$tablename. The runtime db is used to draw the hostgroup hierarchy views 

=cut

sub add_lft_rgt_values {
    my ( $class, $dbname, $tablename ) = @_;
    if ( !$dbname ) {
        ($dbname) = $class->db_Main->{Name} =~ m/database=(\w+)/;
    }
    $tablename ||= $class->table;

    # This recursive function is to set the left and right values of each hostgroup
    # This is from theories as given at http://dev.mysql.com/tech-resources/articles/hierarchical-data.html
    # Need to add dbname and tablename as perl complains that data will not stay shared
    sub rebuild_tree {
        my ( $id, $left, $materialized_path, $dbname, $tablename ) = @_;
        my $right = $left + 1;
        my $dbh   = Opsview->db_Main; # Need inside this recursive function

        my $children = $dbh->selectcol_arrayref(
            "SELECT id FROM hostgroups WHERE parentid=$id ORDER BY name"
        );

        my $name =
          $dbh->selectrow_array( "SELECT name FROM hostgroups WHERE id=?",
            {}, $id );
        if ($materialized_path) {
            $materialized_path .= ",$name";
        }
        else {
            $materialized_path = "$name";
        }

        foreach my $c (@$children) {
            $right = rebuild_tree( $c, $right, $materialized_path, $dbname,
                $tablename );
        }
        $dbh->do(
            "UPDATE $dbname.$tablename SET lft=?, rgt=?, matpath=? WHERE id=?",
            {}, $left, $right, "$materialized_path,", $id
        );
        return $right + 1;
    }

    rebuild_tree( 1, 1, "", $dbname, $tablename );
}

=item typeid

Returns hostgroupX where X is the id of the object

=cut

sub typeid {
    my $self = shift;
    return "hostgroup" . $self->id;
}

=item $self->children

Returns all children of this hostgroup

=cut

sub children {
    my $self = shift;
    return ( $self->search( parentid => $self->id ) );
}

=item $self->is_leaf

Will return true if this hostgroup is a leaf

=cut

__PACKAGE__->set_sql(
    is_leaf => "SELECT ! COUNT(*) FROM __TABLE__ WHERE parentid=?" );

sub is_leaf {
    my $self = shift;
    return $self->sql_is_leaf->select_val( $self->id );
}

=item $self->leaves

Will return an array of leaves from this point of the hostgroup onwards

=cut

# TODO: This could be sped up, big time, with a single query
# and probably the common hostgroup things could be separated and shared between
# Opsview::Hostgroup and Runtime::Hostgroup
sub leaves {
    my $self = shift;
    my @leaves;
    if ( $self->is_leaf ) {
        return $self;
    }
    else {
        foreach my $c ( $self->children ) {
            push @leaves, $c->leaves;
        }
    }
    return @leaves;
}

=item Opsview::Hostgroup->retrieve_by_monitoringserver($ms)

Returns hostgroup objects based on hosts that are monitored by the specified monitoring server.
The master monitoringserver sees all active hosts.

=cut

sub retrieve_by_monitoringserver {
    my ( $class, $ms ) = @_;
    my $dbh = $class->db_Main;

    my $sql;
    my $sth;
    if ( $ms->is_master ) {
        $sql = qq{
SELECT
DISTINCT(hg.id) AS id
FROM
hostgroups hg,
hosts h,
monitoringservers ms
WHERE hg.id = h.hostgroup
AND h.monitored_by = ms.id
AND ms.activated = 1
ORDER BY hg.name
};
        $sth = $dbh->prepare($sql);
        $sth->execute;
    }
    else {
        $sql = qq{
SELECT
DISTINCT(hg.id) AS id
FROM
hostgroups hg,
hosts h
WHERE hg.id = h.hostgroup
AND h.monitored_by = ?
ORDER BY hg.name
};

        $sth = $dbh->prepare_cached($sql);
        $sth->execute( $ms->id );
    }
    return $class->sth_to_objects($sth);
}

=item $self->count_hosts

Returns back number of hosts using this hostgroup

=cut

__PACKAGE__->set_sql(
    count_hosts => "SELECT COUNT(*) FROM hosts WHERE hostgroup = ?" );

sub count_hosts {
    my $self = shift;
    return $self->sql_count_hosts->select_val( $self->id );
}

=item $obj->can_be_changed_by($contact_obj)

Check whether or not the given contact has permisions on the object.

Allowed if ACTIONALL. Also allow if ACTIONSOME and host groups selected via tree
method - we insist on CONFIGUREHOSTGROUPS too because the tree might have been
left for normal users. This should be changed then the access_hostgroups is 
merged with the tree configuration

Returns the object if true, undef if false

=cut

sub can_be_changed_by {
    my ( $self, $contact_obj ) = @_;

    if ( $contact_obj->has_access("ACTIONALL") ) {
        return $self;
    }

    if (   $contact_obj->has_access("ACTIONSOME")
        && $contact_obj->has_access("CONFIGUREHOSTGROUPS") )
    {
        if ( $contact_obj->result_source->schema->resultset("Hostgroups")
            ->restrict_by_user($contact_obj)->search( { id => $self->id } )
            ->count > 0 )
        {
            return $self;
        }
    }

    return;
}

=item my_type_is

Returns "hostgroup"

=cut

sub my_type_is {
    return "hostgroup";
}
sub my_web_type {"hostgroup"}

=item $string = expand_link_macros($string)

Expand any valid nagios macros within string and return

=cut

sub expand_link_macros {
    my ( $self, $string ) = @_;

    $string =~ s/\$HOSTGROUPNAME\$/$self->name/e;

    return $string;
}

=back

=head1 AUTHOR

Opsview Limited

=head1 LICENSE

GNU General Public License v2

=cut

1;
