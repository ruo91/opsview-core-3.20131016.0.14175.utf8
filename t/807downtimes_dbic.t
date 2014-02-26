#!/usr/bin/perl

use Test::More;

use Test::Deep;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Runtime::Schema;

use Opsview::Test qw(stop opsview runtime);
use Test::Perldump::File;

plan 'no_plan';

my $runtime = Runtime::Schema->my_connect;
my $rs      = $runtime->resultset( "OpsviewHostObjects" );

sub flatten_datetime {
    my $hash = shift;
    foreach my $k ( keys %$hash ) {
        if ( ref $hash->{$k} eq "ARRAY" ) {
            my @new_list;
            foreach my $item ( @{ $hash->{$k} } ) {
                push @new_list, flatten_datetime($item);
            }
            $hash->{$k} = \@new_list;
        }
        elsif ( ref $hash->{$k} eq "HASH" ) {
            $hash->{$k} = flatten_datetime( $hash->{$k} );
        }
        elsif ( ref $hash->{$k} eq "DateTime" ) {
            $hash->{$k} = $hash->{$k}->strftime( "%F %T" );
        }
    }
    $hash;
}

my $res = $rs->list_downtimes;
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_full",
    "Result as expected"
) || diag( Data::Dump::dump($res) );

$res = $rs->list_downtimes( { rows => 0 } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_summary_only",
    "Summary data only"
) || diag explain $res;

$res = $rs->list_downtimes( { "hostgroupid" => 5 } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_hg_leaf2",
    "Leaf2 hg only"
) || diag explain $res;

$res = $rs->list_downtimes( { "hostgroupid" => 6 } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_hg_leaf2",
    "Should be same as Leaf2 hg only as only this hg underneath"
) || diag explain $res;

$res = $rs->list_downtimes( { "hostgroupname" => "UK2" } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_hg_leaf2",
    "Should be same as Leaf2 hg only as only this hg underneath"
) || diag explain $res;

$res = $rs->list_downtimes(
    {
        "hostgroupname" => "UK2",
        "hostgroupid"   => 3
    }
);
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_full",
    "Adding extra hostgroupid"
) || diag explain $res;

$res = $rs->list_downtimes( { "hostgroupid" => [ 3, 6 ] } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_full",
    "Result for searching two host groups same as top level"
);

$res = $rs->list_downtimes( { "hostname" => "monitored_by_slave" } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_monitored_by_slave",
    "Downtimes for monitored_by_slave"
);

$res = $rs->list_downtimes( { "hostid" => "136" } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_monitored_by_slave",
    "Downtimes for monitored_by_slave via hostid"
);

$res = $rs->list_downtimes( { "hostname" => "cisco2" } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_cisco2",
    "Downtimes for cisco2"
);

$res = $rs->list_downtimes( { "hostname" => [ "cisco2", "sonnybob" ] } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_cisco2",
    "Downtimes for cisco2 - ignore unknown hosts"
);

$res = $rs->list_downtimes(
    {
        "hostgroupid"   => 9999,
        "hostgroupname" => [ "UK2", "missinghostgroup" ]
    }
);
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_hg_leaf2",
    "Should be same as Leaf2 hg only as only this hg underneath"
) || diag explain $res;

$res = $rs->list_downtimes( { "servicename" => [ "Coldstart", "SSH" ] } );
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_servicenames",
    "Filter by service names"
) || diag explain $res;

$res = $rs->list_downtimes(
    { "hs" => [ "cisco3::Coldstart", "monitored_by_slave::SSH" ] }
);
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_hostservicenames",
    "Filter by hostservice names"
);

$res = $rs->list_downtimes(
    {
        "servicename" => [ "Coldstart",         "SSH" ],
        "hs"          => [ "cisco3::Coldstart", "monitored_by_slave::SSH" ]
    }
);
$res = flatten_datetime($res);
is_perldump_file(
    $res,
    "$Bin/var/perldumps/downtimes_hostservicenames",
    "Filter including hostservice names, but is a subset of service names"
);
