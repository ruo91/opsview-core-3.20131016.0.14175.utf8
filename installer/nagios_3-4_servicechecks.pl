#!/usr/bin/env perl

# If modifying this script, be sure to update the copy on the wiki:
# https://docs.opsview.com/lib/exe/mediamanager.php?ns=opsview4.3:upgrading

# This script will ask the user to modify each Nagios 3 type servicecheck's
# argument to work with Nagios 4. Run with OPSVIEW_TEST=1 to run its tests.

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../perl/lib";
use Test::More;
use Opsview::Utils qw(convert_state_to_text);

my $type_of_run       = 'L'; # 'L'ist only or make 'C'hanges
my $potentials        = 0;
my $recommended       = 0;
my $services_affected = 0;

sub confirm_change {
    my $message = shift;
    my $change_it;
    ++$recommended;
    print $message, $/;
    while (1) {
        print 'y/n? ';
        if ( $type_of_run eq 'L' ) {
            $change_it = 'n';
            print "n\n";
        }
        else {
            $change_it = <>;
            chomp $change_it;
        }
        last if $change_it =~ /^[yn]$/i;
    }
    $change_it = lc $change_it;
    return ( $change_it eq "y" );
}

sub check_all_servicecheck_args {

    require Opsview::Auditlog;
    require Opsview::Schema;
    require Runtime::Schema;

    my $schema  = Opsview::Schema->my_connect;
    my $runtime = Runtime::Schema->my_connect;

    # Get servicechecks with args that contain at least one backslash
    my $servicechecks =
      $schema->resultset('Servicechecks')
      ->search( { args => { '-like' => '%\\\%' } } );

    while ( my $servicecheck = $servicechecks->next ) {
        $potentials++;

        my $scname = $servicecheck->name;

        print "\nSuspect ID: ", $servicecheck->id, ': ', $servicecheck->name,
          "\n";

        my $objects =
          $runtime->resultset("OpsviewHostObjects")
          ->search( { name2 => { "-like" => "$scname%" } } );
        while ( my $object = $objects->next ) {
            my $output = $object->servicestatus->output;
            $output =~ s/\n.*//g;
            print "Host: "
              . $object->hostname
              . " STATE="
              . convert_state_to_text( $object->servicestatus->current_state )
              . " OUTPUT=$output\n";
            ++$services_affected;
        }

        my $before = $servicecheck->args;
        my $after  = convert_nagios3_to_nagios4_syntax($before);

        if ( $after ne $before ) {
            next unless confirm_change( "Change $before\nto     $after" );
            $servicecheck->update(
                {
                    args        => $after,
                    uncommitted => 1,
                }
            );
            Opsview::Auditlog->system(
                    "Arguments for service check '"
                  . $servicecheck->name
                  . "' changed from '$before' to '$after'."
            );
            print "Updated\n";
        }
        else {
            print "No change expected: $before\n";
        }

    }

    # Check host exceptions
    my $hostexceptions =
      $schema->resultset('Servicecheckhostexceptions')
      ->search( { args => { '-like' => '%\\\%' } } );

    while ( my $he = $hostexceptions->next ) {
        $potentials++;

        print "\nSuspect host exception on host: ", $he->host->name,
          ", for service check: ", $he->servicecheck->name,
          "\n";

        my $before = $he->args;
        my $after  = convert_nagios3_to_nagios4_syntax($before);

        if ( $after ne $before ) {
            next unless confirm_change( "Change $before\nto     $after" );
            $he->update( { args => $after } );
            Opsview::Auditlog->system(
                    "Arguments for exception service check '"
                  . $he->servicecheck->name
                  . "' on host "
                  . $he->host->name
                  . " changed from '$before' to '$after'."
            );
            print "Updated\n";
        }
        else {
            print "No change expected: $before\n";
        }

    }

    # Check host template exceptions
    my $hosttemplateexceptions =
      $schema->resultset('Servicecheckhosttemplateexceptions')
      ->search( { args => { '-like' => '%\\\%' } } );

    while ( my $exception = $hosttemplateexceptions->next ) {
        $potentials++;

        print "\nSuspect host template exception on host template: ",
          $exception->hosttemplate->name, ", for service check: ",
          $exception->servicecheck->name,
          "\n";

        my $before = $exception->args;
        my $after  = convert_nagios3_to_nagios4_syntax($before);

        if ( $after ne $before ) {
            next unless confirm_change( "Change $before\nto     $after" );
            $exception->update( { args => $after } );
            Opsview::Auditlog->system(
                    "Arguments for exception service check '"
                  . $exception->servicecheck->name
                  . "' on host template "
                  . $exception->hosttemplate->name
                  . " changed from '$before' to '$after'."
            );
            print "Updated\n";
        }
        else {
            print "No change expected: $before\n";
        }

    }

    # Check host timed exceptions
    my $hosttimedexceptions =
      $schema->resultset('Servicechecktimedoverridehostexceptions')
      ->search( { args => { '-like' => '%\\\%' } } );

    while ( my $exception = $hosttimedexceptions->next ) {
        $potentials++;

        print "\nSuspect host timed override exception on host: ",
          $exception->host->name, ", for service check: ",
          $exception->servicecheck->name,
          "\n";

        my $before = $exception->args;
        my $after  = convert_nagios3_to_nagios4_syntax($before);

        if ( $after ne $before ) {
            next unless confirm_change( "Change $before\nto     $after" );
            $exception->update( { args => $after } );
            Opsview::Auditlog->system(
                    "Arguments for timed exception service check '"
                  . $exception->servicecheck->name
                  . "' on host "
                  . $exception->host->name
                  . " changed from '$before' to '$after'."
            );
            print "Updated\n";
        }
        else {
            print "No change expected: $before\n";
        }

    }

    # Check host template timed exceptions
    my $hosttemplatetimedexceptions =
      $schema->resultset('Servicechecktimedoverridehosttemplateexceptions')
      ->search( { args => { '-like' => '%\\\%' } } );

    while ( my $exception = $hosttemplatetimedexceptions->next ) {
        $potentials++;

        print
          "\nSuspect host template Timed override exception on host template: ",
          $exception->hosttemplate->name, ", for service check: ",
          $exception->servicecheck->name,
          "\n";

        my $before = $exception->args;
        my $after  = convert_nagios3_to_nagios4_syntax($before);

        if ( $after ne $before ) {
            next unless confirm_change( "Change $before\nto     $after" );
            $exception->update( { args => $after } );
            Opsview::Auditlog->system(
                    "Arguments for timed exception service check '"
                  . $exception->servicecheck->name
                  . "' on host template "
                  . $exception->hosttemplate->name
                  . " changed from '$before' to '$after'."
            );
            print "Updated\n";
        }
        else {
            print "No change expected: $before\n";
        }

    }

    if ( $potentials == 0 ) {
        print
          "Cannot find any arguments to service checks that look like they will be an issue\n";
        return;
    }
}

# We use special cases for things from the initial database that may flag appear
# where the rules cannot possibly change to the correct value
# When copying, backslashes need to be double escaped
my $special_cases =
  { q{-H $HOSTADDRESS$ -c nsc_checkcounter -a '\"MaxCrit=12 MaxWarn=6 \Counter=\\\\PhysicalDisk(0 C:)\\\\Avg. Disk Read Queue Length\"'}
      => q{-H $HOSTADDRESS$ -c nsc_checkcounter -a 'MaxCrit=12 MaxWarn=6 "Counter=\PhysicalDisk(0 C:)\Avg. Disk Read Queue Length"'},
  };

sub convert_nagios3_to_nagios4_syntax {
    my $in = shift;

    if ( $_ = $special_cases->{$in} ) {
        return $_;
    }

    $in =~ s/\\"/"/g;

    my @before = split /(['"])/, $in;
    my @after = @before;

    for ( my $i = 0; $i < scalar @after - 1; ++$i ) {
        if (    $after[ $i - 1 ] =~ /^['"]$/
            and $after[ $i + 1 ] =~ /^['"]$/
            and $after[$i] !~ / -/ )
        {
            $after[$i] =~ s/([^\\])\\([^\\])/$1$2/g;
            if ( $after[ $i - 1 ] eq "'" ) {
                $after[$i] =~ s/\\\\/\\/g;
            }
        }
    }

    my $after = join '', @after;
    $after
      =~ s/^([^'"]+)'([^"]*?)"\\\\(.+?)\\\\(.+?)"([^']+)'/$1'$2"\\$3\\$4"$5'/;

    return $after;
}

sub back_up_db {
    print "Backing up opsview database\n";
    system(
        "$Bin/../bin/db_opsview db_backup | gzip --fast --stdout > $Bin/../var/backups/opsview-db-`date +'%Y-%m-%d-%H%M'`-nagios_3-4-servicechecks.gz"
      ) == 0
      or die "Did not make a back-up of the opsview database: $?";
}

if ( $ENV{OPSVIEW_TEST} ) {
    while ( my $description = <DATA> ) {
        my $old_syntax = <DATA>;
        my $new_syntax = <DATA>;
        my $emptyline  = <DATA>;
        chomp $description;
        chomp $old_syntax;
        chomp $new_syntax;
        is( convert_nagios3_to_nagios4_syntax($old_syntax),
            $new_syntax, $description );
    }
    done_testing();
}
else {
    print
      "Would you like to make changes as we go (C) or list recommended changes (L)? ";
    while (1) {
        print 'C/L? ';
        $type_of_run = <>;
        chomp $type_of_run;
        $type_of_run = uc $type_of_run;
        last if $type_of_run =~ /^[CL]$/;
    }
    back_up_db() if $type_of_run eq 'C';
    check_all_servicecheck_args();
    print "\n";
    print "This was a trial run, nothing has been changed.\n"
      if $type_of_run eq 'L';
    print "Number of service checks spotted with a backslash: $potentials\n";
    print
      "Number of service checks that we recommend to be changed: $recommended\n";
    print "Number of services possibly affected: $services_affected\n";
}

__DATA__
Special case - Ton cannot confirm if this ever worked, but was in initial database and the target is definitely right
-H $HOSTADDRESS$ -c nsc_checkcounter -a '\"MaxCrit=12 MaxWarn=6 \Counter=\\PhysicalDisk(0 C:)\\Avg. Disk Read Queue Length\"'
-H $HOSTADDRESS$ -c nsc_checkcounter -a 'MaxCrit=12 MaxWarn=6 "Counter=\PhysicalDisk(0 C:)\Avg. Disk Read Queue Length"'

WMI check
-H $HOSTADDRESS$ -c CheckWMI -a Query:EnabledState='Select EnabledState from Msvm_ComputerSystem where ElementName=\"%VIRTUAL_MACHINE_NAME%\"' 'namespace=root\\virtualization' MinCrit=0 MaxCrit=2
-H $HOSTADDRESS$ -c CheckWMI -a Query:EnabledState='Select EnabledState from Msvm_ComputerSystem where ElementName="%VIRTUAL_MACHINE_NAME%"' 'namespace=root\virtualization' MinCrit=0 MaxCrit=2

Basic check
-H "$HOSTADDRESS$"
-H "$HOSTADDRESS$"

C Drive
-H $HOSTADDRESS$ -c nsc_checkdrivesize -a 'Drive=C: MinWarnFree=10% MinCritFree=5%'
-H $HOSTADDRESS$ -c nsc_checkdrivesize -a 'Drive=C: MinWarnFree=10% MinCritFree=5%'

CPU Utilisation
-H $HOSTADDRESS$ -c nsc_checkcpu -a 'warn=90 crit=95 time=10m time=1m ShowAll=long'
-H $HOSTADDRESS$ -c nsc_checkcpu -a 'warn=90 crit=95 time=10m time=1m ShowAll=long'

Multiple Drive: C
-H $HOSTADDRESS$ -c nsc_checkdrivesize -a 'Drive=%DISK%: MinWarnFree=10% MinCritFree=5%'
-H $HOSTADDRESS$ -c nsc_checkdrivesize -a 'Drive=%DISK%: MinWarnFree=10% MinCritFree=5%'

Paging File Utilisation
-H $HOSTADDRESS$ -c nsc_checkmem -a 'MaxWarn=80% MaxCrit=90% ShowAll type=page'
-H $HOSTADDRESS$ -c nsc_checkmem -a 'MaxWarn=80% MaxCrit=90% ShowAll type=page'

Physical Memory
-H $HOSTADDRESS$ -c nsc_checkmem -a 'MaxWarn=80% MaxCrit=90% ShowAll type=physical'
-H $HOSTADDRESS$ -c nsc_checkmem -a 'MaxWarn=80% MaxCrit=90% ShowAll type=physical'

Win - Opsview Agent Threads
-H $HOSTADDRESS$ -c CheckWMIValue -a Query='select Caption, ThreadCount from Win32_Process where caption=\"NSClient++.exe\"' MaxWarn=50 MaxCrit=100 Check:threads=ThreadCount AliasCol=Caption ShowAll
-H $HOSTADDRESS$ -c CheckWMIValue -a Query='select Caption, ThreadCount from Win32_Process where caption="NSClient++.exe"' MaxWarn=50 MaxCrit=100 Check:threads=ThreadCount AliasCol=Caption ShowAll

Win Hyper-V - Image Management Service
-H $HOSTADDRESS$ -c CheckServiceState -a ShowAll \"Hyper-V Image Management Service\"
-H $HOSTADDRESS$ -c CheckServiceState -a ShowAll "Hyper-V Image Management Service"

Win Hyper-V - Instance IDs
-H $HOSTADDRESS$ -c CheckWMI -a Query='Select ElementName,InstanceID from Msvm_VirtualSystemSettingData' namespace='root\\virtualization'
-H $HOSTADDRESS$ -c CheckWMI -a Query='Select ElementName,InstanceID from Msvm_VirtualSystemSettingData' namespace='root\virtualization'

Win Hyper-V - Management Instance ID
-H $HOSTADDRESS$ -c CheckWMI -a Query='Select InstanceID from Msvm_VirtualSystemManagementServiceSettingData' namespace='root\\virtualization'
-H $HOSTADDRESS$ -c CheckWMI -a Query='Select InstanceID from Msvm_VirtualSystemManagementServiceSettingData' namespace='root\virtualization'

Win Hyper-V - Networking Management Service
-H $HOSTADDRESS$ -c CheckServiceState -a ShowAll \"Hyper-V Networking Management Service\"
-H $HOSTADDRESS$ -c CheckServiceState -a ShowAll "Hyper-V Networking Management Service"

Win Hyper-V - TESTING
-H $HOSTADDRESS$ -c CheckWMI -a Query='Select * from Msvm_VirtualSystemManagementServiceSettingData' namespace='root\\virtualization'
-H $HOSTADDRESS$ -c CheckWMI -a Query='Select * from Msvm_VirtualSystemManagementServiceSettingData' namespace='root\virtualization'

Win Hyper-V - Total Running VMs
-H $HOSTADDRESS$ -c CheckWMI -a Query:quantity='Select ElementName from Msvm_ComputerSystem where EnabledState=\"2\"' namespace='root\\virtualization' MinWarn=1 MaxWarn=4
-H $HOSTADDRESS$ -c CheckWMI -a Query:quantity='Select ElementName from Msvm_ComputerSystem where EnabledState="2"' namespace='root\virtualization' MinWarn=1 MaxWarn=4

Win Hyper-V - Virtual Machine Management Service
-H $HOSTADDRESS$ -c CheckServiceState -a ShowAll \"Hyper-V Virtual Machine Management\"
-H $HOSTADDRESS$ -c CheckServiceState -a ShowAll "Hyper-V Virtual Machine Management"

Win Hyper-V - VM Status: ov-hv-win7-demo
-H $HOSTADDRESS$ -c CheckWMI -a Query:EnabledState='Select EnabledState from Msvm_ComputerSystem where ElementName=\"%VIRTUAL_MACHINE_NAME%\"' 'namespace=root\\virtualization' MinCrit=0 MaxCrit=2
-H $HOSTADDRESS$ -c CheckWMI -a Query:EnabledState='Select EnabledState from Msvm_ComputerSystem where ElementName="%VIRTUAL_MACHINE_NAME%"' 'namespace=root\virtualization' MinCrit=0 MaxCrit=2

Another WMI check
-H $HOSTADDRESS$ -c CheckWMIValue -a Query='select Caption, ThreadCount from Win32_Process where caption=\"NSClient++.exe\"' MaxWarn=50 MaxCrit=100 Check:threads=ThreadCount AliasCol=Caption ShowAll
-H $HOSTADDRESS$ -c CheckWMIValue -a Query='select Caption, ThreadCount from Win32_Process where caption="NSClient++.exe"' MaxWarn=50 MaxCrit=100 Check:threads=ThreadCount AliasCol=Caption ShowAll

Win Event Log
-H $HOSTADDRESS$ -c CheckEventLog -a file=Application \"filter=generated gt -2d AND severity NOT IN ('success', 'informational')\" MaxWarn=1 MaxCrit=10
-H $HOSTADDRESS$ -c CheckEventLog -a file=Application "filter=generated gt -2d AND severity NOT IN ('success', 'informational')" MaxWarn=1 MaxCrit=10

Win Event log - Security Events
-H $HOSTADDRESS$ -c CheckEventLog -a file=Security \"filter=generated gt -2d AND severity NOT IN ('success', 'informational')\" MaxWarn=1 MaxCrit=10
-H $HOSTADDRESS$ -c CheckEventLog -a file=Security "filter=generated gt -2d AND severity NOT IN ('success', 'informational')" MaxWarn=1 MaxCrit=10

Win Hyper-V Guest Shutdown
-H $HOSTADDRESS$ -c CheckServiceState -a ShowAll \"Hyper-V Guest Shutdown Service\"
-H $HOSTADDRESS$ -c CheckServiceState -a ShowAll "Hyper-V Guest Shutdown Service"

Escaped string required by shell needs to remain
-H $HOSTADDRESS$ -u /login?a=b\&app=dummy -s 'colorgrey30">dummy</div>'
-H $HOSTADDRESS$ -u /login?a=b\&app=dummy -s 'colorgrey30">dummy</div>'

Escaped string within single quotes can be removed
-H $HOSTADDRESS$ -u '/login?a=b\&app=dummy' -s 'colorgrey30">dummy</div>'
-H $HOSTADDRESS$ -u '/login?a=b&app=dummy' -s 'colorgrey30">dummy</div>'

Escaped string within double quotes can be removed
-H $HOSTADDRESS$ -u "/login?a=b\&app=dummy" -s 'colorgrey30">dummy</div>'
-H $HOSTADDRESS$ -u "/login?a=b&app=dummy" -s 'colorgrey30">dummy</div>'

Kielder2 filepath
-H $HOSTADDRESS$ -c nsc_checkdrivesize -a 'Drive=\\\\KIELDER2\\Sentinel MinWarnFree=10% MinCritFree=5%'
-H $HOSTADDRESS$ -c nsc_checkdrivesize -a 'Drive=\\KIELDER2\Sentinel MinWarnFree=10% MinCritFree=5%'

Double backslash in double quotes
-H $HOSTADDRESS$ -v COUNTER -l "\\Memory\\Available Bytes",'%.f'
-H $HOSTADDRESS$ -v COUNTER -l "\\Memory\\Available Bytes",'%.f'

Double backslash in single quotes
-H $HOSTADDRESS$ -v COUNTER -l '\\Memory\\Available Bytes','%.f'
-H $HOSTADDRESS$ -v COUNTER -l '\Memory\Available Bytes','%.f'

Double quoted backslash somewhere inside single quotes
-H $HOSTADDRESS$ -c nsc_checkcounter -a '"\\MSExchangeTransport Queues(_total)\\Largest Delivery Queue Length" MaxWarn=100 MaxCrit=200 ShowAll'
-H $HOSTADDRESS$ -c nsc_checkcounter -a '"\MSExchangeTransport Queues(_total)\Largest Delivery Queue Length" MaxWarn=100 MaxCrit=200 ShowAll'
