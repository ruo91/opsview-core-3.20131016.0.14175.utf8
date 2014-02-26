#!/bin/sh

# check_constraints.sh
# --------------------
# Check foreign key contraints on MySQL database.
#
# Written by Frank Vanderhallen, licensed under GPL.

if [ -z "$1" ]
then
printf "\nUsage:\n\t./`basename $0` [-h <host>] [-u user] [-p<passwd>] <database>\n"
exit
fi

CONSTRAINTS=`mysqldump $* | grep "CREATE\|CONSTRAINT" | sed 's/ /+/g'`
errors=0

for c in $CONSTRAINTS
do
if [ "`echo $c | cut -d '+' -f 3`" = "CONSTRAINT" ]
then
CONSTRAINT=`echo $c | cut -d '+' -f 4 | tr -d '\`'`
CHILD_KEY=`echo $c | cut -d '+' -f 7 | tr -d '()\`,'`
PARENT_TABLE=`echo $c | cut -d '+' -f 9 | tr -d '\`'`
PARENT_KEY=`echo $c | cut -d '+' -f 10 | tr -d '()\`,'`
QUERY="select c.$CHILD_KEY from $CHILD_TABLE as c left join $PARENT_TABLE as p on p.$PARENT_KEY=c.$CHILD_KEY where c.$CHILD_KEY is not null and p.$PARENT_KEY is null;"
echo "Checking table '$CHILD_TABLE' constraint '$CONSTRAINT'"
mysql --table --verbose -e "$QUERY" $*
else
CHILD_TABLE=`echo $c | cut -d '+' -f 3`
fi
done
