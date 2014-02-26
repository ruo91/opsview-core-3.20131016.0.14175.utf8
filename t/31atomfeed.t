#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 143;

#use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "t/lib";
use File::Compare;
use Storable qw(retrieve_fd store_fd);
use Fcntl qw(:flock);
use POSIX qw(strftime);
use Data::Dump qw(dump);

my $tests_per_set = 13;
my $sets          = 3;

#plan tests => $sets * $tests_per_set;

my $nagiosdir     = "/usr/local/nagios";
my $storefile     = "$nagiosdir/atom/testuser.store";
my $notify_by_rss = "$nagiosdir/libexec/notifications/notify_by_rss";

{
    my $test = 0;

    sub read_next_data_set() {
        while ( my $line = <DATA> ) {
            chomp($line);
            last if ( $line =~ m/^=-=-=-/ );
            next if ( $line =~ /^#/ );
            my @line = split( /=/, $line );
            $ENV{ $line[0] } = $line[1] || "";
        }
        return ++$test;
    }
}

sub w3cdtf {
    return strftime '%Y-%m-%dT%H:%M:%SZ', localtime(shift);
}

sub parse_data {
    my %data;

    if ( $ENV{NAGIOS_SERVICEDESC} ) {
        $data{alert_type} = "service";
        $data{item_uuid}  = 'host:'
          . $ENV{NAGIOS_HOSTNAME}
          . ';service:'
          . $ENV{NAGIOS_SERVICEDESC};
        $data{title} = "$ENV{NAGIOS_HOSTNAME} - $ENV{NAGIOS_SERVICEDESC}";
        $data{state} = $ENV{NAGIOS_SERVICESTATE};
        $data{url_params} =
          "?type=2&host=$ENV{NAGIOS_HOSTNAME}&service=$ENV{NAGIOS_SERVICEDESC}";
        $data{output}            = $ENV{NAGIOS_SERVICEOUTPUT};
        $data{author}            = $ENV{NAGIOS_SERVICEACKAUTHOR};
        $data{ackcomment}        = $ENV{NAGIOS_SERVICEACKCOMMENT};
        $data{last_state_change} = $ENV{NAGIOS_LASTSERVICESTATECHANGE};
    }
    else {
        $data{alert_type}        = "host";
        $data{item_uuid}         = 'host:' . $ENV{NAGIOS_HOSTNAME};
        $data{title}             = "$ENV{NAGIOS_HOSTNAME}";
        $data{state}             = $ENV{NAGIOS_HOSTSTATE};
        $data{url_params}        = "?type=1&host=$ENV{NAGIOS_HOSTNAME}";
        $data{output}            = $ENV{NAGIOS_HOSTOUTPUT};
        $data{author}            = $ENV{NAGIOS_HOSTACKAUTHOR};
        $data{ackcomment}        = $ENV{NAGIOS_HOSTACKCOMMENT};
        $data{last_state_change} = $ENV{NAGIOS_LASTHOSTSTATECHANGE};
    }

    if ( $data{author} ) {
        $data{output}
          .= "<br /><br />Acknowledged by: $data{author}<br />Comment: $data{ackcomment}";
    }

    if ( $ENV{NAGIOS_NOTIFICATIONTYPE} eq "ACKNOWLEDGEMENT" ) {
        $data{state} = "ACKNOWLEDGEMENT of $data{state}";
    }

    $data{time} = $ENV{NAGIOS_TIMET};

    $data{id} = $data{item_uuid} . ":" . $data{last_state_change};

    return %data;
}

sub read_store_file($) {
    my $test = shift;
    my $entry;

    ok( -f $storefile, "($test) store file created - " . $storefile );

    open( STORE, "<", $storefile );
    flock( STORE, LOCK_SH );
    $entry = retrieve_fd(*STORE);
    close(STORE);

    ok( $entry, "($test) data inserted" );

    #print dump( $entry->[0] ), $/;

    return $entry->[0];
}

sub basic_tests($$%) {
    my $test  = shift;
    my $entry = shift;
    my %data  = @_;

    if (   $entry->{last_update} > time() - 10
        && $entry->{last_update} < time() + 10 )
    {
        pass( "($test) Checking last_update" );
    }
    else {
        fail( "($test) Checking last_update" );
    }
    is( $entry->{internal_id}, $data{item_uuid}, "($test) Checking internal_id"
    );

    #is($entry->{id}, $data{item_uuid}.":". $data{last_state_change}, "($test) Checking id");
    #	is($entry->{id}, $data{id}, "($test) Checking id");
    is(
        $entry->{title},
        "$data{state}: $data{title}",
        "($test) Checking title"
    );
    is( $entry->{link},    $data{url_params},     "($test) Checking link" );
    is( $entry->{updated}, w3cdtf( $data{time} ), "($test) Checking updated" );
    is( $entry->{content}, $data{output},         "($test) Checking content" );
    is( $entry->{state},   $data{state},          "($test) Checking state" );
    is( $entry->{author} || "", $data{author}, "($test) Checking author" );
}

# ==== initial entry - host up
my $test = read_next_data_set();
my %data = parse_data();

if ( -f $storefile && $ENV{CLEANOUT} ) {
    unlink("$nagiosdir/atom/testuser.store")
      or die( "Unable to remove testuser.store" );
}

system($notify_by_rss);

my $entry = read_store_file($test);
basic_tests( $test, $entry, %data );

# this should be correct on initial submission, and unchanged after
is( $entry->{published}, w3cdtf( $data{time} ), "($test) Checking published" );
is( $entry->{author},    undef,                 "check author undefined" );
is( $entry->{id},        $data{id},             "Is uuid the same" );

# ==== update entry - host still up

$test = read_next_data_set();
my %data2 = parse_data();

system($notify_by_rss);

pass( "($test) $ENV{SETNAME}" );

$entry = read_store_file($test);
basic_tests( $test, $entry, %data2 );

is( $entry->{published}, w3cdtf( $data{time} ), "Is published time the same" );
is( $data{id},           $data2{id},            "Is uuid the same" );
is( $data{internal_id}, $data2{internal_id}, "Is updated internal_id the same"
);
is( $entry->{author}, undef, "check author undefined" );

# ==== update entry - host down

$test = read_next_data_set();
my %data3 = parse_data();

system($notify_by_rss);

pass( "($test) $ENV{SETNAME}" );

$entry = read_store_file($test);
basic_tests( $test, $entry, %data3 );

is(
    $entry->{published},
    w3cdtf( $data3{time} ),
    "Is published time different"
);
isnt( $data{id}, $data3{id}, "Is uuid different" );
is( $data{internal_id}, $data3{internal_id}, "Is updated internal_id the same"
);
is( $entry->{author}, undef, "check author undefined" );

# ==== update entry - host down but ACK'ed

$test = read_next_data_set();
my %data4 = parse_data();

system($notify_by_rss);

pass( "($test) $ENV{SETNAME}" );

$entry = read_store_file($test);
basic_tests( $test, $entry, %data4 );
is( $entry->{author}, $data4{author}, "Is author stated" );
is( $entry->{id},     $data3{id},     "Is uuid the same" );

# ==== update entry - host back up

$test = read_next_data_set();
my %data5 = parse_data();

system($notify_by_rss);

pass( "($test) $ENV{SETNAME}" );

$entry = read_store_file($test);
basic_tests( $test, $entry, %data5 );

is( $entry->{published}, w3cdtf( $data3{time} ), "Is published time the same"
);
is( $entry->{id}, $data3{id}, "Is uuid the same" );
is( $data{internal_id}, $data2{internal_id}, "Is updated internal_id the same"
);
is( $entry->{author}, undef, "check author undefined" );

# ==== initial entry - service up
$test = read_next_data_set();
%data = parse_data();

if ( -f $storefile && $ENV{CLEANOUT} ) {
    unlink("$nagiosdir/atom/testuser.store")
      or die( "Unable to remove testuser.store" );
}

system($notify_by_rss);

$entry = read_store_file($test);
basic_tests( $test, $entry, %data );

# this should be correct on initial submission, and unchanged after
is( $entry->{published}, w3cdtf( $data{time} ), "($test) Checking published" );
is( $entry->{author}, undef, "check author undefined" );

# ==== update entry - service still up

$test  = read_next_data_set();
%data2 = parse_data();

system($notify_by_rss);

pass( "($test) $ENV{SETNAME}" );

$entry = read_store_file($test);
basic_tests( $test, $entry, %data2 );

is( $entry->{published}, w3cdtf( $data{time} ), "Is published time the same" );
is( $data{id},           $data2{id},            "Is updated uuid the same" );
is( $data{internal_id}, $data2{internal_id}, "Is updated internal_id the same"
);
is( $entry->{author}, undef, "check author undefined" );

# ==== update entry - service down

$test  = read_next_data_set();
%data3 = parse_data();

system($notify_by_rss);

pass( "($test) $ENV{SETNAME}" );

$entry = read_store_file($test);
basic_tests( $test, $entry, %data3 );

is(
    $entry->{published},
    w3cdtf( $data3{time} ),
    "Is published time different"
);
isnt( $data{id}, $data3{id}, "Is updated uuid different" );
is( $data{internal_id}, $data3{internal_id}, "Is updated internal_id the same"
);
is( $entry->{author}, undef, "check author undefined" );

# ==== update entry - service down but ACK'ed

$test  = read_next_data_set();
%data4 = parse_data();

system($notify_by_rss);

pass( "($test) $ENV{SETNAME}" );

$entry = read_store_file($test);
basic_tests( $test, $entry, %data4 );
is(
    $entry->{published},
    w3cdtf( $data3{time} ),
    "Is published time different"
);
isnt( $data{id}, $data3{id}, "Is uuid the same" );
is( $data{internal_id}, $data4{internal_id}, "Is internal_id the same" );
is( $entry->{author},   $data4{author},      "Is author stated" );

# ==== update entry - service back up

$test  = read_next_data_set();
%data5 = parse_data();

system($notify_by_rss);

pass( "($test) $ENV{SETNAME}" );

$entry = read_store_file($test);
basic_tests( $test, $entry, %data5 );

is( $entry->{published}, w3cdtf( $data3{time} ), "Is published time the same"
);
is( $entry->{id}, $data3{id}, "Is uuid the same" );
is( $data{internal_id}, $data2{internal_id}, "Is updated internal_id the same"
);
is( $entry->{author}, undef, "check author undefined" );

__DATA__
# test data section
SETNAME=data set 1 - new host up
CLEANOUT=1;
NAGIOS_TIMET=1184916000
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_HOSTSTATETYPE=HARD
NAGIOS_HOSTOUTPUT=OK - host ok
NAGIOS_HOSTACKAUTHOR=
NAGIOS_HOSTACKCOMMENT=
NAGIOS_LASTHOSTSTATECHANGE=1184916000
NAGIOS_NOTIFICATIONTYPE=OK
NAGIOS_HOSTSTATE=UP
=-=-=-
SETNAME=data set 2 - repeat host up
CLEANOUT=0;
NAGIOS_TIMET=1184916050
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_HOSTSTATETYPE=HARD
NAGIOS_HOSTOUTPUT=OK - host ok
NAGIOS_HOSTACKAUTHOR=
NAGIOS_HOSTACKCOMMENT=
NAGIOS_LASTHOSTSTATECHANGE=1184916000
NAGIOS_NOTIFICATIONTYPE=OK
NAGIOS_HOSTSTATE=UP
=-=-=-
SETNAME=data set 3 - update to host down
CLEANOUT=0;
NAGIOS_TIMET=1184916100
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_HOSTSTATETYPE=HARD
NAGIOS_HOSTOUTPUT=CRITICAL - Host Unreachable (dev19.dud.altinity)
NAGIOS_HOSTACKAUTHOR=
NAGIOS_HOSTACKCOMMENT=
NAGIOS_LASTHOSTSTATECHANGE=1184916100
NAGIOS_NOTIFICATIONTYPE=PROBLEM
NAGIOS_HOSTSTATE=DOWN
=-=-=-
SETNAME=data set 4 - update to host down ACK'ed
CLEANOUT=0;
NAGIOS_TIMET=1184916150
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_HOSTSTATETYPE=HARD
NAGIOS_HOSTOUTPUT=CRITICAL - Host Unreachable (dev19.dud.altinity)
NAGIOS_HOSTACKAUTHOR=testuser2
NAGIOS_HOSTACKCOMMENT=Acknowledged
NAGIOS_LASTHOSTSTATECHANGE=1184916100
NAGIOS_NOTIFICATIONTYPE=ACKNOWLEDGEMENT
NAGIOS_HOSTSTATE=DOWN
=-=-=-
SETNAME=data set 5 - updated to host up
CLEANOUT=0;
NAGIOS_TIMET=1184916200
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_HOSTSTATETYPE=HARD
NAGIOS_HOSTOUTPUT=OK - host ok
NAGIOS_HOSTACKAUTHOR=
NAGIOS_HOSTACKCOMMENT=
NAGIOS_LASTHOSTSTATECHANGE=1184916200
NAGIOS_NOTIFICATIONTYPE=OK
NAGIOS_HOSTSTATE=UP
=-=-=-
SETNAME=data set 6 - new service up
CLEANOUT=1;
NAGIOS_TIMET=1184916000
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_SERVICESTATE=OK
NAGIOS_SERVICEDESC=SSH
NAGIOS_SERVICEOUTPUT=TCP OK - 0.006 second response time on port 22
NAGIOS_SERVICEACKAUTHOR=
NAGIOS_SERVICEACKCOMMENT=
NAGIOS_LASTSERVICESTATECHANGE=1184916000
=-=-=-
SETNAME=data set 7 - repeat service up
CLEANOUT=0;
NAGIOS_TIMET=1184916050
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_SERVICESTATE=OK
NAGIOS_SERVICEDESC=SSH
NAGIOS_SERVICEOUTPUT=TCP OK - 0.006 second response time on port 22
NAGIOS_SERVICEACKAUTHOR=
NAGIOS_SERVICEACKCOMMENT=
NAGIOS_LASTSERVICESTATECHANGE=1184916000
=-=-=-
SETNAME=data set 8 - update to service critical
CLEANOUT=0;
NAGIOS_TIMET=1184916100
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_SERVICESTATE=CRITICAL
NAGIOS_SERVICEDESC=SSH
NAGIOS_SERVICEOUTPUT=Connection refused
NAGIOS_SERVICEACKAUTHOR=
NAGIOS_SERVICEACKCOMMENT=
NAGIOS_LASTSERVICESTATECHANGE=1184916100
=-=-=-
SETNAME=data set 9 - update to service critical ACK'ed
CLEANOUT=0;
NAGIOS_TIMET=1184916150
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_SERVICESTATE=CRITICAL
NAGIOS_SERVICEDESC=SSH
NAGIOS_SERVICEOUTPUT=Connection refused
NAGIOS_SERVICEACKAUTHOR=testuser2
NAGIOS_SERVICEACKCOMMENT=Acknowledged
NAGIOS_LASTSERVICESTATECHANGE=1184916100
=-=-=-
SETNAME=data set 10 - updated service up
CLEANOUT=0;
NAGIOS_TIMET=1184916000
NAGIOS_CONTACTNAME=testuser
NAGIOS_HOSTNAME=host1
NAGIOS_HOSTADDRESS=host1.domain.name
NAGIOS_SERVICESTATE=OK
NAGIOS_SERVICEDESC=SSH
NAGIOS_SERVICEOUTPUT=TCP OK - 0.006 second response time on port 22
NAGIOS_SERVICEACKAUTHOR=
NAGIOS_SERVICEACKCOMMENT=
NAGIOS_LASTSERVICESTATECHANGE=1184916000
