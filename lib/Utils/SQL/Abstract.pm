# This module is duplicated from DBIx::Class::Storage::DBI
# Original authors: Matt S Trout and Andy Grundman
# Used to get HAVING and GROUP BY support in SQL::Abstract
package Utils::SQL::Abstract;

use warnings;
use strict;
use SQL::Abstract;
use base qw/SQL::Abstract/;

sub _recurse_fields {
    my ( $self, $fields, $params ) = @_;
    my $ref = ref $fields;
    return $self->_quote($fields) unless $ref;
    return $$fields if $ref eq 'SCALAR';

    if ( $ref eq 'ARRAY' ) {
        return join(
            ', ',
            map {
                $self->_recurse_fields($_)
                  . (
                    exists $self->{rownum_hack_count}
                      && !( $params && $params->{no_rownum_hack} )
                    ? ' AS col' . $self->{rownum_hack_count}++
                    : ''
                  )
              } @$fields
        );
    }
    elsif ( $ref eq 'HASH' ) {
        foreach my $func ( keys %$fields ) {
            return
                $self->_sqlcase($func) . '( '
              . $self->_recurse_fields( $fields->{$func} ) . ' )';
        }
    }
}

sub _order_by {
    my $self = shift;
    my $ret  = '';
    my @extra;
    if ( ref $_[0] eq 'HASH' ) {
        if ( defined $_[0]->{group_by} ) {
            $ret = $self->_sqlcase(' group by ')
              . $self->_recurse_fields(
                $_[0]->{group_by},
                { no_rownum_hack => 1 }
              );
        }
        if ( defined $_[0]->{having} ) {
            my $frag;
            ( $frag, @extra ) = $self->_recurse_where( $_[0]->{having} );
            push( @{ $self->{having_bind} }, @extra );
            $ret .= $self->_sqlcase(' having ') . $frag;
        }
        if ( defined $_[0]->{order_by} ) {
            $ret .= $self->_order_by( $_[0]->{order_by} );
        }
    }
    else {
        $ret = $self->SUPER::_order_by(@_);
    }
    return $ret;
}

sub select {
    my ( $self, $table, $fields, $where, $order, @rest ) = @_;
    local $self->{having_bind} = [];
    my ( $sql, @ret ) =
      $self->SUPER::select( $table, $fields, $where, $order, @rest );
    return wantarray ? ( $sql, @ret, @{ $self->{having_bind} } ) : $sql;
}

1;
