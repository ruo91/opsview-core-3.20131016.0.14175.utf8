
package Opsview::Utils::Plugins;

use Moose;
use File::Basename qw( basename );
use Try::Tiny;

has 'db_schema' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_db_schema',
);

has 'db_resultset' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_db_resultset',
);

has 'plugins_using_help' => (
    is       => 'ro',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_plugins_using_help',
);

has 'plugin_execution_timeout' => (
    is      => 'ro',
    default => 10,
);

sub _build_db_schema {
    require Opsview::Schema;

    return Opsview::Schema->my_connect;
}

sub _build_db_resultset {
    my ($self) = @_;

    return $self->db_schema->resultset( "Plugins" );
}

sub _build_plugins_using_help {
    return +{
        map { $_ => 1 }
          qw(
          check_cluster
          )
    };
}

sub examine_plugin {
    my ( $self, $plugin ) = @_;

    my $uses_help = $self->plugins_using_help;

    my $basename = basename($plugin);

    my @command = $plugin;
    push @command, exists $uses_help->{$basename} ? "--help" : "-h";
    push @command, "2>/dev/null";

    my @output;
    my $envvars;
    if ( $ENV{OPSVIEW_TEST} ) {
        @output = ( "testmode!" );
    }
    else {
        $envvars = $self->parse_plugin_for_envvars($plugin);

        my $timeout = $self->plugin_execution_timeout;

        #my $rc;
        try {
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm $timeout;
            @output = `@command`;
            alarm 0;

            #$rc = $? >> 8;
        }
        catch {
            @output = ( "Timeout $timeout seconds running @command\n" );
            if ( $_ ne "alarm\n" ) {
                push @output, "Details: $_";
            }
        };

        # Cannot do below as it is not defined what the return code from -h is
        #if ($rc != 0) {
        #    @output = ("Error gathering help for $command: rc=$rc");
        #}
    }

    return {
        name     => $basename,
        onserver => 1,
        help     => join( "", @output ),
        envvars  => $envvars || "",
    };
}

sub examine_directory_plugins {
    my ( $self, $dir ) = @_;

    my @data;

    my @plugins = ( glob("$dir/check_*"), "$dir/negate", "$dir/urlize" );
    foreach my $plugin (@plugins) {
        next if ( $plugin =~ /\.dpkg-tmp/ );
        next if ( $plugin =~ /\.tmp/ );
        next if ( $plugin =~ /\.bak/ );

        push @data, $self->examine_plugin($plugin);
    }

    return @data;
}

sub populate_db {
    my ( $self, $plugins_data ) = @_;

    my $plugins_rs = $self->db_resultset;

    for my $data ( @{ $plugins_data || [] } ) {
        my $obj = $plugins_rs->update_or_create($data);
    }
}

sub parse_plugin_for_envvars {
    my ( $self, $plugin ) = @_;
    my @envvars;

    # If text file
    return "" unless -T $plugin;

    open F, $plugin or return "";
    my $inside = 0;
    while (<F>) {
        if (/^### BEGIN OPSVIEW INFO/) {
            $inside = 1;
        }
        elsif ($inside) {
            if (/^### END OPSVIEW INFO/) {
                last;
            }
            elsif (/^# Macros:\s*([\w,]+)/) {
                push @envvars, $1;
            }
        }
    }
    close F;

    return join( ",", @envvars );
}

__PACKAGE__->meta->make_immutable;

1;

