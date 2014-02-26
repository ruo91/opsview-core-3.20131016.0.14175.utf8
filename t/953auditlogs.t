#!/usr/bin/perl
# Tests for Opsview::ResultSet::Auditlogs

use Test::More qw(no_plan);

use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Schema;
use Opsview::Test qw(opsview);
use Opsview::Auditlog;

my $schema = Opsview::Schema->my_connect;

my $obj;
my $expected;
my $h;
my $rs = $schema->resultset( "Auditlogs" );

Opsview::Auditlog->create(
    {
        username => "duncs",
        text     => "More work than a busy squirrel"
    }
);
Opsview::Auditlog->create(
    {
        text     => "Backup completed",
        reloadid => 555
    }
);
Opsview::Auditlog->system( "some text here" );
Opsview::Auditlog->system( "some more system stuff" );
Opsview::Auditlog->create(
    {
        username => "tonnie",
        text     => "Bad robot"
    }
);

my $last_backup_auditid = $rs->search(
    { reloadid => { ">" => 0 } },
    {
        rows     => 1,
        order_by => { "-desc" => "id" }
    }
)->first->id;
is( $last_backup_auditid, 2, );

my $changes = $rs->search(
    {
        "username" => { "!=" => "" },
        "id"       => { ">"  => $last_backup_auditid }
    }
)->count;
is( $changes, 1, "Should only have 1 entry counted" );

my $max_auditid = $rs->get_column("id")->max;
is( $max_auditid, 5 );
