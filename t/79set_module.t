#!/usr/bin/perl

use Test::More qw(no_plan);

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../etc";
use Opsview::Test;
use Opsview::Schema;

my $set_module = "$Bin/../installer/set_module";

sub run_set_module {
    system("$set_module @_") == 0;
}

sub run_set_module_with_output {
    my @output = `$set_module @_`;
    return \@output;
}

my $schema = Opsview::Schema->my_connect;

is(
    run_set_module('--name "Invisible" --enabled=0 --url "/invisible"'),
    1, "Created new module menu"
);

my $module =
  $schema->resultset("Modules")
  ->find( { namespace => "thirdparty.invisible" } );
is( $module->enabled, 0, "Not enabled" );
is( $module->url, "/invisible" );
is( $module->description, "" );
is( $module->name,        "Invisible" );

is(
    run_set_module(
        '--name "Jasperserver" --enabled=1 --url="/jasperserver" --version="1.1.1" --namespace="com.opsview.modules.reports" --description="Opsview Enterprise Reports" --access="REPORTADMIN"'
    ),
    1,
    "Created new module menu"
);
$module =
  $schema->resultset("Modules")
  ->find( { namespace => "com.opsview.modules.reports" } );
is( $module->enabled,     1 );
is( $module->url,         "/jasperserver" );
is( $module->description, "Opsview Enterprise Reports" );
is( $module->version,     "1.1.1" );
is( $module->name,        "Jasperserver" );
is( $module->access,      "REPORTADMIN" );

is(
    run_set_module(
        '--name "Jasperserver" --enabled=1 --url="/jasperserver" --version="1.1.2" --namespace="com.opsview.modules.reports" --description="Opsview Enterprise Reports" --access=""'
    ),
    1,
    "Updated module menu"
);
$module =
  $schema->resultset("Modules")
  ->find( { namespace => "com.opsview.modules.reports" } );
is( $module->enabled,     1 );
is( $module->url,         "/jasperserver" );
is( $module->description, "Opsview Enterprise Reports" );
is( $module->version,     "1.1.2" );
is( $module->name,        "Jasperserver" );
is( $module->access,      "" );

is(
    run_set_module(
        '--name "Jasperserver" --namespace="com.opsview.modules.reports" --enabled=0'
    ),
    1,
    "Deinstalled Reports module menu"
);
$module =
  $schema->resultset("Modules")
  ->find( { namespace => "com.opsview.modules.reports" } );
is( $module->enabled, 0, "Deinstalled reports" );
is( $module->url, "/jasperserver", 'url is correct' );
is( $module->description, "Opsview Enterprise Reports", 'description ok' );

$module = $schema->resultset("Modules")->synchronise(
    {
        namespace   => "thirdparty.invisible",
        description => 'Invisible menu item',
        access      => 'ADMINACCESS',
    }
);

is( $module->enabled,     0,                     'invisible still disabled' );
is( $module->description, 'Invisible menu item', 'description updated' );
is( $module->access,      'ADMINACCESS',         'correct access' );

my $output = run_set_module_with_output(
    '--name "Jasperserver" --namespace="com.opsera.opsview.modules.report" --enabled=1'
);
is_deeply(
    $output,
    [
        "Ignoring this module as it is not compatible with Opsview v4: com.opsera.opsview.modules.report\n"
    ],
    "Got message due to old namespace parameters"
);
