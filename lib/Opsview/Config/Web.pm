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

package Opsview::Config::Web;
use strict;
use Opsview::Config;
use Config::Any;
use Catalyst::Utils;

my $config_root = Opsview::Config->web_root_dir;

my $web_config;

#This part duplicates how Catalyst reads the configuration files
sub web_config {
    return $web_config if $web_config;
    my $files =
      [ "$config_root/opsview_web.yml", "$config_root/opsview_web_local.yml" ];
    my $input = Config::Any->load_files(
        {
            files   => $files,
            use_ext => 1,
        }
    );
    my ( @cfg, @localcfg );
    for (@$input) {
        if ( ( keys %$_ )[0] =~ m/_local\./ ) {
            push @localcfg, $_;
        }
        else {
            push @cfg, $_;
        }
    }
    my $cfg = {};
    for ( @cfg, @localcfg ) {
        my ( $file, $config ) = each %$_;
        $cfg = Catalyst::Utils::merge_hashes( $cfg, $config );
    }
    return $web_config = $cfg;
}

1;
