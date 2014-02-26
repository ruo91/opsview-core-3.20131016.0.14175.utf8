#!/bin/bash

# Tests that certain processes are started after opsview is started.
#<<<

trap 'restart' EXIT
function restart {
    /usr/local/nagios/bin/rc.opsview restart
    echo "1..$i"
}

function ok {
    (( i = $i + 1 ))
    if $1 > /dev/null; then
        echo "ok $i - $2"
    else
        echo "not ok $i - $2"
    fi
}

function not_ok {
    (( i = $i + 1 ))
    if ! $1 > /dev/null; then
        echo "ok $i - $2"
    else
        echo "not ok $i - $2"
    fi
}

i=0

/usr/local/nagios/bin/rc.opsview stop
pkill -fx import_ndoconfigend  || true
pkill -fx import_ndologsd      || true
pkill -fx import_perfdatarrd   || true
pkill -fx import_slaveresultsd || true
pkill -x nagios                || true
pkill -x nrd                   || true
pkill -x nsca                  || true
pkill -x opsviewd              || true

ok "/usr/local/nagios/bin/rc.opsview start" "Opsview started as a master"

ok     'pgrep -fx import_ndoconfigend'  "import_ndoconfigend is running"
ok     'pgrep -fx import_ndologsd'      "import_ndologsd is running"
ok     'pgrep -fx import_perfdatarrd'   "import_perfdatarrd is running"
not_ok 'pgrep -fx import_slaveresultsd' "import_slaveresultsd is not running"
ok     'pgrep -x nagios'                "nagios is running"
ok     'pgrep -x nrd'                   "nrd is running"
ok     'pgrep -x nsca'                  "nsca is running"
ok     'pgrep -x opsviewd'              "opsviewd is running"

# vim:filetype=sh
#>>>
