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

package Opsview::ResultSet::MonitorPacks;

use strict;
use warnings;

use base qw/Opsview::ResultSet/;
use Opsview::Utils qw(convert_to_arrayref);

use Log::Log4perl;
use version;
use JSON qw(decode_json);
use Try::Tiny;
use File::Copy;
use File::Copy::Recursive qw(rcopy);
use File::Path;
use Cwd;
use List::MoreUtils qw(uniq);
use Opsview::Utils::Plugins;

sub monitor_pack_dir {
    my $dir = "/usr/local/nagios/var/spool/opspacks";
    if ( !-e $dir ) {
        mkdir $dir || die "Cannot create $dir";
    }
    $dir;
}

sub read_info {
    my ( $self, $filename ) = @_;

    my $info = {};

    open F, $filename or die "Not here $filename: $!";
    while (<F>) {
        next if /^#/;
        if (/^([A-Z_]+)=(.*)$/) {
            my $k = lc $1;
            $info->{$k} = $2;
        }
    }
    close F;

    return $info;
}

sub add_plugins {
    my ( $self, $packdir, $logger, $schema ) = @_;

    my $plugindir = "/usr/local/nagios/libexec";
    my @plugins;
    if ( !opendir DIR, "$packdir/plugins" ) {

        # NOTE: some opspacks do not contain plugins, but make use of
        # already installed ones
        $logger->debug(
            "Cannot open $packdir/plugins/ - assuming no plugins in pack"
        );
        return;
    }

    # Log message if plugin already exists
    @plugins = grep !/^\.\.?/, readdir DIR;
    closedir DIR;

    my $plugins_rs = $schema->resultset( "Plugins" );

    my $plugin_util = Opsview::Utils::Plugins->new();
    foreach my $pname (@plugins) {
        my $p = $plugins_rs->find_or_new( { name => $pname } );

        if ( $p->in_storage ) {
            $logger->warn(
                "Plugin '$pname' already exists - overwriting with opspack version"
            );
        }

        $logger->info( "Adding plugin: $pname" );
        my $plugin    = "$packdir/plugins/$pname";
        my $to_plugin = "$plugindir/$pname";

        # Ensure file is writable if at all possible
        # Don't bother error checking as the subsequent copy will fail if the chmod is unsuccessful
        if ( -e $to_plugin && !-w _ ) {
            chmod( 0755, $to_plugin );
        }
        copy( $plugin, $plugindir ) or do {
            $logger->error( "Cannot copy $plugin to $plugindir: $!" );
            next;
        };
        chmod( 0755, $to_plugin ) or do {
            $logger->error(
                "Cannot change mode of $to_plugin to 0755 after upgrade: $!"
            );
            next;
        };

        my $data = $plugin_util->examine_plugin( "$plugindir/$pname" );
        delete $data->{name};
        $p->set_columns($data);

        if ( !$p->in_storage ) {

            # Just use a dummy message for now. The next populatedb.pl will get the right help
            $p->insert;
        }
        else {
            $p->update;
        }
    }

    # TODO: Use plugins.d/PLUGINNAME, rather than plugins.d/PACKNAME
    # Will need to go over all plugins to find references to plugins.d
    # Copy 'plugins.d' dir.
    #if ( -d "$packdir/plugins.d" ) {
    #    $logger->info( "Installing extra files for $packdir" );
    #
    #    opendir DIR, "$packdir/plugins.d" or do {
    #        $logger->error( "Cannot read $packdir/plugins.d: $!" );
    #        return;
    #    };
    #    my @plugins = grep !/^\.\.?/, readdir DIR;
    #    closedir DIR;
    #    foreach my $p (@plugins) {
    #        my $dest = "$plugindir/plugins.d/$p";
    #        rmtree($dest) if -d $dest;
    #        rcopy( "$packdir/plugins.d/$p", $dest ) or do {
    #            $logger->error(
    #                "Could not move $packdir/plugins.d into $dest: $!"
    #            );
    #            next;
    #        };
    #        $logger->info( "Installed into $dest" );
    #    }
    #
    #}
}

sub check_conflicts {
    my ( $self, $config_perl, $schema ) = @_;
    my @errors;

    # Duplicated service groups and keywords are allowed
    # Check attributes
    foreach my $at ( @{ $config_perl->{attribute} } ) {
        if ( $schema->resultset("Attributes")->find( { name => $at->{name} } ) )
        {
            push @errors, "Attribute '" . $at->{name} . "' already exists";
        }
    }

    # Check service checks
    foreach my $sc ( @{ $config_perl->{servicecheck} } ) {
        if (
            $schema->resultset("Servicechecks")->find( { name => $sc->{name} } )
          )
        {
            push @errors, "Service check '" . $sc->{name} . "' already exists";
        }
    }

    # Check host templates
    foreach my $ht ( @{ $config_perl->{hosttemplate} } ) {
        if (
            $schema->resultset("Hosttemplates")->find( { name => $ht->{name} } )
          )
        {
            push @errors, "Host template '" . $ht->{name} . "' already exists";
        }
    }
    return @errors;
}

# Assume this is invoked from the monitorpacks directory
# Will die if failures found
sub install_pack {
    my ( $self, $filename, $opts ) = @_;
    $opts ||= {};

    my $schema = $self->result_source->schema;

    my $force = $opts->{force};

    my $logger = $opts->{logger};
    unless ($logger) {
        Log::Log4perl::init( "/usr/local/nagios/etc/Log4perl.conf" );
        $logger = Log::Log4perl->get_logger( "opspacks" );
    }
    if ( $opts->{stdout} ) {
        my $stdout_appender = Log::Log4perl::Appender->new(
            "Log::Log4perl::Appender::Screen",
            name   => "screenlog",
            stderr => 0,
        );
        $logger->add_appender($stdout_appender);
    }

    my $packdir = $filename;
    $packdir =~ s/\.tar\.gz$//;

    # TODO: Should this be based on mtime? Or read version numbers?
    if ( -e $packdir ) {
        $logger->info( "Found older version of $packdir - deleting" );
        rmtree($packdir);
    }

    $logger->debug( "Uncompressing $filename" );
    my $rc = system( "tar", "--gzip", "-xf", $filename );
    if ( $rc != 0 ) {
        $logger->logdie( "Cannot uncompress $filename: rc=$?" );
    }

    if ( !-e $packdir ) {
        $logger->logdie( "$packdir not found - invalid monitoring pack" );
    }

    # Need to touch the top level dir so that will not re-untar the file next time round
    utime time(), time(), $packdir;

    my $info = $self->read_info("$packdir/info")
      or $logger->logdie( "Cannot read $packdir/info" );

    foreach my $k (qw(name version alias)) {
        $logger->logdie("No $k in $packdir/info") unless $info->{$k};
    }

    my $mpid = "Opspack '" . $info->{alias} . "'";

    # Check Opsview minimum version
    if ( $info->{opsview_min_version} ) {
        if ( version->parse( Opsview::Config->opsview_version )
            <= version->parse( $info->{opsview_min_version} ) )
        {
            $logger->logdie( "Error: Minimum Opsview version for opspack '"
                  . $info->{alias} . "' is "
                  . $info->{opsview_min_version}
                  . " but currently on "
                  . Opsview::Config->opsview_version );
        }
    }

    # Add plugins here, regardless of opspack version
    $self->add_plugins( $packdir, $logger, $schema );

    # This should belong in add_plugins, when the plugins.d
    # changes to be plugin based
    if ( -d "$packdir/plugin.d" ) {
        $logger->info( "Installing extra files for $packdir" );

        my $dest = "/usr/local/nagios/libexec/plugins.d/$packdir";
        rmtree($dest) if -d $dest;
        rcopy( "$packdir/plugin.d", $dest ) or do {
            $logger->logdie( "Could not move $packdir/plugins.d into $dest: $!"
            );
        };
    }

    my $mpack = $self->find_or_new( { name => $info->{name} } );
    unless ( $mpack->in_storage ) {
        $mpack->insert;
    }
    elsif ( !$force ) {
        if ( $mpack->status ne "OK" ) {
            if ( $mpack->status eq "NOTICE" ) {
                $logger->warn(
                    "$mpid marked as NOTICE state - will try to reinstall"
                );
            }
            else {
                $logger->error(
                    "$mpid already installed in state " . $mpack->status );
                return undef;
            }
        }
        if ( version->parse( $mpack->version )
            == version->parse( $info->{version} ) )
        {
            $logger->info(
                "$mpid - version $info->{version} is already installed"
            );
            rmtree($packdir);
            return 1;
        }
        elsif ( version->parse( $mpack->version )
            > version->parse( $info->{version} ) )
        {
            $logger->error(
                    "$mpid installed version "
                  . $mpack->version
                  . " is greater than "
                  . $info->{version}
            );
            return undef;
        }
    }
    $mpack->update(
        {
            alias        => $info->{alias},
            dependencies => $info->{dependencies},
            status       => "INSTALLING",
        }
    );

    # Check dependencies - TODO
    my @deps = $self->parse_dependencies( $info->{dependencies} );

    # Read config.json
    open F, "$packdir/config.json" or do {
        $mpack->update( { status => "FAILURE" } );
        $logger->logdie( "Cannot open $packdir/config.json" );
    };
    my $config_perl;
    {
        local $/;
        my $json_text = <F>;
        $config_perl = decode_json($json_text);
    }
    close F;

    # Do a check before hand to see if any duplication already exists
    my @errors = $self->check_conflicts( $config_perl, $schema );

    # If errors
    #  If force, we log messages
    #  Else we mark the install as NOTICE so that we can do a reinstall next time
    if (@errors) {
        if ($force) {
            my $message = "$mpid - errors found, but continuing with import: "
              . join( ", ", @errors );
            $logger->info($message);
        }
        else {
            my $message = "$mpid - errors found. No import attempted: "
              . join( ", ", @errors );
            $mpack->update(
                {
                    message => $message,
                    status  => "NOTICE"
                }
            );
            $logger->warn($message);
            return undef;
        }
    }

    # Make config DB changes
    my $error_message;
    try {
        $logger->info( "Importing from $packdir" );
        my $guard = $schema->txn_scope_guard;

        my $sync_opts = {};
        unless ($force) {
            $sync_opts->{create_only} = 1;
        }

        # Update keywords
        foreach my $kw ( @{ $config_perl->{keyword} } ) {
            $logger->info( "Adding keyword: " . $kw->{name} );
            $schema->resultset("Keywords")
              ->synchronise( $kw, { %$sync_opts, create_only => 0 } );
        }

        # Update service groups
        foreach my $sg ( @{ $config_perl->{servicegroup} } ) {
            $logger->info( "Adding servicegroup: " . $sg->{name} );
            $schema->resultset("Servicegroups")
              ->synchronise( $sg, { %$sync_opts, create_only => 0 } );
        }

        # Update attributes
        foreach my $at ( @{ $config_perl->{attribute} } ) {
            $logger->info( "Adding attribute: " . $at->{name} );
            $schema->resultset("Attributes")->synchronise( $at, $sync_opts );
        }

        # Update service checks - not cascaded_from first
        foreach my $sc (
            sort {
                ( defined $a->{cascaded_from} ? 1 : 0 )
                  <=> ( defined $b->{cascaded_from} ? 1 : 0 )
            } @{ $config_perl->{servicecheck} }
          )
        {
            $logger->info( "Adding service check: " . $sc->{name} );
            $schema->resultset("Servicechecks")->synchronise( $sc, $sync_opts );
        }

        # Update host templates
        foreach my $ht ( @{ $config_perl->{hosttemplate} } ) {
            $logger->info( "Adding host template: " . $ht->{name} );
            $schema->resultset("Hosttemplates")->synchronise( $ht, $sync_opts );
        }

        $guard->commit;
    }
    catch {
        $error_message = $_;
    };

    # Update $mpack with result
    if ( defined $error_message ) {
        $mpack->update(
            {
                status  => "FAILURE",
                message => $error_message
            }
        );
        $logger->error( "$mpid - database update failed: $error_message" );
        return undef;
    }

    $mpack->update(
        {
            status  => "OK",
            version => $info->{version},
            message => ""
        }
    );

    rmtree($packdir);

    $logger->info( "$mpid - finished installation" );
    return 1;
}

sub parse_dependencies {
    my ( $self, $deps ) = @_;
    return split( /\s+/, $deps );
}

sub dependency_tree {
    my ( $self, $all_packs_array ) = @_;

    my @packs;

    # TODO: Work out dependency tree
    # We cheat for the moment. We'll just add opsview-agent to the front of the list until proper
    # dependency trees can be calculated
    foreach my $p (@$all_packs_array) {
        if ( $p eq "os-opsview-agent.tar.gz" ) {
            unshift @packs, $p;
        }
        else {
            push @packs, $p;
        }
    }

    return uniq @packs;

}

sub install_new_monitorpacks {
    my ( $self, $logger, $opts ) = @_;

    my $monitorpackdir = $opts->{dir} || $self->monitor_pack_dir;
    my $cwd = getcwd;
    chdir($monitorpackdir)
      or $logger->logdie( "Cannot chdir to $monitorpackdir" );

    opendir DIR, ".";
    my @monitorpacks = grep { !/^\.\.?/ && /\.tar\.gz$/ } sort readdir DIR;
    closedir DIR;

    unless (@monitorpacks) {
        $logger->logdie( "No opspacks found" );
    }

    @monitorpacks = $self->dependency_tree( \@monitorpacks );

    my $errors = 0;
    foreach my $mp (@monitorpacks) {
        ( my $packdir = $mp ) =~ s/\.tar\.gz//;

        #$logger->debug( "Reading: $packdir/info" );
        #my $info = $self->read_info( "$packdir/info" );

        # skip already installed OpsPacks
        #if ( $self->find( { name => $info->{name} } ) ) {
        #    $logger->info(
        #        "Skipping $info->{alias} ($info->{name} already installed)"
        #    );
        #    next;
        #}

        # Run install_monitorpack
        my $rc;
        try {
            $rc = $self->install_pack(
                $mp,
                {
                    logger => $logger,
                    %$opts
                }
            );
            unless ($rc) {
                $errors++;
            }
        }
        catch {
            $logger->error( "Exception: $_" );
            $errors++;
        }

    }

    chdir($cwd);
    $logger->debug( "Errors=$errors" );
    return ( $errors == 0 ? 1 : 0 );
}

1;
