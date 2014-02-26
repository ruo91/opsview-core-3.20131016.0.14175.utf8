#!/usr/bin/perl
# Tests for Opsview::ResultSet, using Hosts

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);
use Opsview;

my $schema = Opsview::Schema->my_connect;

my $rs = $schema->resultset( "Hosts" );

my $relationships_many = $rs->relationships_many;
my @errors             = ();

my $res = $rs->expand_foreign_object(
    {
        rel => "servicechecks",
        rs  => $rs->result_source->schema->resultset(
            $relationships_many->{"servicechecks"}
        ),
        search => { name => "Events" },
        errors => \@errors
    }
);

isa_ok( $res, "Opsview::Schema::Servicechecks" );

# Cause a failure in the expand_foreign_object call
Opsview->db_Main->do(
    "ALTER TABLE servicechecks DROP COLUMN flap_detection_enabled"
);

eval {
    $res = $rs->expand_foreign_object(
        {
            rel => "servicechecks",
            rs  => $rs->result_source->schema->resultset(
                $relationships_many->{"servicechecks"}
            ),
            search => { name => "Events" },
            errors => \@errors
        }
    );
};

like(
    $@,
    qr/Unknown column 'me.flap_detection_enabled' in 'field list'/,
    'DB exception caught'
);
