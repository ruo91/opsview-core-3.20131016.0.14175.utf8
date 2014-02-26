#!/usr/bin/perl

use Test::More qw(no_plan);

use Test::Deep;

use FindBin qw($Bin);
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../etc";
use strict;
use Runtime;
use Runtime::Searches;
use Runtime::Service;
use Runtime::Hostgroup;
use Opsview;
use Opsview::Schema;
use Runtime::Schema;
use Opsview::Test;

# If this fails, run perl t/802status.t nodb resetperldumps
# and check with svn diff -x -b
use Test::Perldump::File;

my $dbh = Runtime->db_Main;

my $schema  = Opsview::Schema->my_connect;
my $runtime = Runtime::Schema->my_connect;

my $contact =
  $schema->resultset("Contacts")->search( { name => "admin" } )->first;
my $non_admin =
  $schema->resultset("Contacts")->search( { name => "nonadmin" } )->first;
my $somehosts =
  $schema->resultset("Contacts")->search( { name => "somehosts" } )->first;
my $readonly =
  $schema->resultset("Contacts")->search( { name => "readonly" } )->first;

my $hostgroup = Runtime::Hostgroup->retrieve(1);

my $status;

$status =
  Runtime::Searches->list_services( $contact, { hostgroupid => $hostgroup->id }
  );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_full",
    "Got expected data (full) for admin contact"
);

$status =
  $runtime->resultset("OpsviewHostObjects")
  ->list_summary( { hostgroupid => 1 } );
my $dt_formatter = Opsview::Test->dt_formatter;
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_full",
    "DBIx wizardry!"
) || diag explain $status;

$status =
  Runtime::Searches->list_services( $non_admin,
    { hostgroupid => $hostgroup->id }
  );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_full",
    "Got expected data (full) for non admin contact"
);

$status =
  Runtime::Searches->list_services( $readonly,
    { hostgroupid => $hostgroup->id }
  );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_full",
    "Got expected data (full) for readonly contact"
);

$status =
  Runtime::Searches->list_services( $somehosts,
    { hostgroupid => $hostgroup->id }
  );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_one_host",
    "Got expected subset of data for 'somehosts' contact"
);

$status =
  $runtime->resultset("OpsviewHostObjects")
  ->search( { "contacts.contactid" => $somehosts->id }, { join => "contacts" } )
  ->list_summary( { hostgroupid => 1 } );
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_one_host",
    "DBIx wizardry!"
) || diag explain $status;

$status =
  Runtime::Searches->list_services( $contact, { host => "monitored_by_slave" }
  );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_one_host",
    "Got search by host"
);

$status =
  $runtime->resultset("OpsviewHostObjects")
  ->list_summary( { host => "monitored_by_slave" } );
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_one_host",
    "DBIx wizardry!"
) || diag explain $status;

$status =
  Runtime::Searches->list_services( $contact,
    { host => [qw(monitored_by_slave opslave)] }
  );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_two_hosts",
    "Got search by host, multiple times"
);

$status =
  $runtime->resultset("OpsviewHostObjects")
  ->list_summary( { host => [qw(monitored_by_slave opslave)] } );
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_two_hosts",
    "DBIx wizardry!"
) || diag explain $status;

$status = Runtime::Searches->list_services(
    $contact,
    {
        host  => [qw(monitored_by_slave opslave)],
        order => [qw(host_desc service)]
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_hosts_reordered",
    "Got search by host, multiple times reordered"
);

$status = $runtime->resultset("OpsviewHostObjects")->list_summary(
    {
        host  => [qw(monitored_by_slave opslave)],
        order => [qw(host_desc service)]
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_hosts_reordered",
    "DBIx wizardry!"
) || diag explain $status;

$status = Runtime::Searches->list_services(
    $contact,
    {
        host  => [qw(monitored_by_slave opslave)],
        order => [qw(state_desc host service)]
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_state_reorder",
    "Reorder by service state"
);

$status = $runtime->resultset("OpsviewHostObjects")->list_summary(
    {
        host  => [qw(monitored_by_slave opslave)],
        order => [qw(state_desc host service)]
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_state_reorder",
    "DBIx wizardry!"
) || diag explain $status;

$status = Runtime::Searches->list_services(
    $contact,
    {
        host  => [qw(monitored_by_slave opslave)],
        order => [qw(state_desc host service)],
        state => [qw(0 2)],
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_state_filter",
    "Filter by states"
);

$status = $runtime->resultset("OpsviewHostObjects")->list_summary(
    {
        host  => [qw(monitored_by_slave opslave)],
        order => [qw(state_desc host service)],
        state => [qw(0 2)],
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_state_filter",
    "DBIx wizardry!"
) || diag explain $status;

$status = Runtime::Searches->list_services(
    $contact,
    {
        hostgroupid => $hostgroup->id,
        filter      => 'handled'
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_handled",
    "Got expected data (handled) for admin contact"
);

$status = $runtime->resultset("OpsviewHostObjects")->list_summary(
    {
        hostgroupid => $hostgroup->id,
        filter      => "handled"
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_handled",
    "DBIx wizardry!"
) || diag explain $status;

$status = Runtime::Searches->list_services(
    $non_admin,
    {
        hostgroupid => $hostgroup->id,
        filter      => 'handled'
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_handled",
    "Got expected data (handled) for non admin contact"
);

my $empty = {
    list    => [],
    summary => {
        host => {
            unhandled => 0,
            handled   => 0,
            total     => 0
        },
        service => {
            unhandled => 0,
            handled   => 0,
            total     => 0
        },
        total     => 0,
        handled   => 0,
        unhandled => 0,
    }
};

$status = Runtime::Searches->list_services(
    $somehosts,
    {
        hostgroupid => $hostgroup->id,
        filter      => 'handled'
    }
);
cmp_deeply( $status, noclass($empty),
    "Got expected data (handled) for 'somehosts' contact"
);

$status =
  $runtime->resultset("OpsviewHostObjects")
  ->search( { "contacts.contactid" => $somehosts->id }, { join => "contacts" } )
  ->list_summary(
    {
        hostgroupid => $hostgroup->id,
        filter      => "handled"
    }
  );
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_deeply( $status, $empty, "DBIx wizardry!" ) || diag explain $status;

# Test with includeunhandledhosts - this is the All Unhandled link on left hand nav

$status = Runtime::Searches->list_services(
    $contact,
    {
        hostgroupid           => $hostgroup->id,
        filter                => 'unhandled',
        includeunhandledhosts => 1
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_includeunhandled",
    "Got expected data (unhandled with includeunhandledhosts) for admin contact"
);

$status = $runtime->resultset("OpsviewHostObjects")->list_summary(
    {
        hostgroupid           => $hostgroup->id,
        filter                => "unhandled",
        includeunhandledhosts => 1
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_includeunhandled",
    "DBIx wizardry!"
) || diag explain $status;

$status = Runtime::Searches->list_services(
    $non_admin,
    {
        hostgroupid           => $hostgroup->id,
        filter                => 'unhandled',
        includeunhandledhosts => 1
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_includeunhandled",
    "Got expected data (unhandled with includeunhandledhosts) for non admin contact"
);

$status = Runtime::Searches->list_services(
    $somehosts,
    {
        hostgroupid           => $hostgroup->id,
        filter                => 'unhandled',
        includeunhandledhosts => 1
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_includeunhandled_somehosts",
    "Got expected data (unhandled with includeunhandledhosts) for 'somehosts' contact"
);

$status =
  $runtime->resultset("OpsviewHostObjects")
  ->search( { "contacts.contactid" => $somehosts->id }, { join => "contacts" } )
  ->list_summary(
    {
        hostgroupid           => $hostgroup->id,
        filter                => "unhandled",
        includeunhandledhosts => 1
    }
  );
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_includeunhandled_somehosts",
    "DBIx wizardry!"
) || diag explain $status;

# Test without includeunhandledhosts - these are linked off HH pages

$status = Runtime::Searches->list_services(
    $contact,
    {
        hostgroupid => $hostgroup->id,
        filter      => 'unhandled'
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_unhandled",
    "Got expected data (unhandled) for admin contact"
);

$status = $runtime->resultset("OpsviewHostObjects")->list_summary(
    {
        hostgroupid => $hostgroup->id,
        filter      => "unhandled"
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_unhandled",
    "DBIx wizardry!"
) || diag explain $status;

$status = Runtime::Searches->list_services(
    $non_admin,
    {
        hostgroupid => $hostgroup->id,
        filter      => 'unhandled'
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_unhandled",
    "Got expected data (unhandled) for non admin contact"
);

$status = Runtime::Searches->list_services(
    $somehosts,
    {
        hostgroupid => $hostgroup->id,
        filter      => 'unhandled'
    }
);
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_unhandled_somehosts",
    "Got expected data (unhandled) for 'somehosts' contact"
);

$status =
  $runtime->resultset("OpsviewHostObjects")
  ->search( { "contacts.contactid" => $somehosts->id }, { join => "contacts" } )
  ->list_summary(
    {
        hostgroupid => $hostgroup->id,
        filter      => "unhandled"
    }
  );
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_unhandled_somehosts",
    "DBIx wizardry!"
) || diag explain $status;

$status = Runtime::Searches->list_services( $readonly, { changeaccess => 1 } );
cmp_deeply( $status, noclass($empty),
    "Got empty data when requesting change list for readonly user"
);

$status = $runtime->resultset("OpsviewHostObjects")->list_summary(
    {
        keyword               => "cisco",
        includehandleddetails => 1
    }
);
Opsview::Utils->convert_all_values_to_string( $status, $dt_formatter );
Opsview::Test->strip_field_from_hash( "state_duration", $status );
is_perldump_file(
    $status,
    "$Bin/var/perldumps/services_handleddetails",
    "DBIx wizardry!"
) || diag explain $status;

$status = $runtime->resultset("OpsviewHostObjects")->list_service_objects(
    {
        rows        => 7,
        servicename => "%a%"
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/service_lookup_group_by_host",
    "service lookup group by host"
) || diag explain $status;

$status = $runtime->resultset("OpsviewHostObjects")->list_service_objects(
    {
        group_by    => "service",
        rows        => 7,
        servicename => "%a%"
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/service_lookup_group_by_service",
    "service lookup group by service"
) || diag explain $status;

$status = $runtime->resultset("OpsviewHostObjects")->list_service_objects(
    {
        group_by    => "host",
        distinct    => 1,
        rows        => 5,
        servicename => "%o%"
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/service_lookup_group_by_host_distinct",
    "service lookup group by host distinct"
) || diag explain $status;

$status = $runtime->resultset("OpsviewHostObjects")->list_service_objects(
    {
        group_by    => "service",
        distinct    => 1,
        rows        => 5,
        servicename => "%o%"
    }
);
is_perldump_file(
    $status,
    "$Bin/var/perldumps/service_lookup_group_by_service_distinct",
    "service lookup group by service distinct"
) || diag explain $status;
