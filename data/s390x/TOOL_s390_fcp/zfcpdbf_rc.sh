# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash
#set -x

for i in `ls lib/*.sh`; do source $i || exit 8; done


adapter=$1
wwpn=$2
lun=$3

tool_path=$(s390_get_tool_path zfcpdbf)

init_tests

start_section 0 "TOOL:zfcpdbf test"

mount |grep debugfs

if [ $? = 0 ]
then
echo debugfs is already mounted, do nothing!;echo
else
echo debugfs is not mounted, mounting debugfs on /sys/kernel/debug;echo

mount -t debugfs none /sys/kernel/debug
fi


assert_exec 0  "$tool_path --help"
assert_exec 0  "$tool_path -h"

assert_exec 0  "$tool_path --version"
assert_exec 0  "$tool_path -v"

assert_exec 1  "$tool_path"
assert_exec 0  "$tool_path $adapter  >> results.log"
assert_exec 0  "$tool_path $adapter -f  >> results.log"
assert_exec 0  "$tool_path $adapter --force  >> results.log"

assert_exec 0  "$tool_path -i REC $adapter  >> results.log"
assert_exec 0  "$tool_path -i HBA $adapter  >> results.log"
assert_exec 0  "$tool_path -i SAN $adapter  >> results.log"
assert_exec 0  "$tool_path -i SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path -i QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path -i QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path -i QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path -i CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path -i CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path -i CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path -i KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path -i MULTIPATH $adapter  >> results.log"

assert_exec 0  "$tool_path --include REC $adapter  >> results.log"
assert_exec 0  "$tool_path --include HBA $adapter  >> results.log"
assert_exec 0  "$tool_path --include SAN $adapter  >> results.log"
assert_exec 0  "$tool_path --include SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path --include QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path --include QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path --include QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path --include CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path --include CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path --include CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path --include KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path --include MULTIPATH $adapter  >> results.log"


assert_exec 0  "$tool_path -x REC $adapter  >> results.log"
assert_exec 0  "$tool_path -x HBA $adapter  >> results.log"
assert_exec 0  "$tool_path -x SAN $adapter  >> results.log"
assert_exec 0  "$tool_path -x SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path -x QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path -x QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path -x QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path -x CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path -x CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path -x CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path -x KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path -x MULTIPATH $adapter  >> results.log"


assert_exec 0  "$tool_path --exclude REC $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude HBA $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude SAN $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path --exclude MULTIPATH $adapter  >> results.log"

assert_exec 0  "$tool_path -z $adapter  >> results.log"
assert_exec 0  "$tool_path --zfcp-only $adapter  >> results.log"

assert_exec 0  "$tool_path -p /sys/kernel/debug/s390dbf $adapter  >> results.log"
assert_exec 0  "$tool_path --path=/sys/kernel/debug/s390dbf $adapter  >> results.log"

assert_exec 0  "$tool_path -e $adapter  >> results.log"
assert_exec 0  "$tool_path --def-error $adapter  >> results.log"

assert_exec 0  "$tool_path -t 5 $adapter  >> results.log"
assert_exec 0  "$tool_path --timediff=5 $adapter  >> results.log"

assert_exec 0  "$tool_path -r / $adapter  >> results.log"
assert_exec 0  "$tool_path --root=/ $adapter  >> results.log"

#################Additional scenarios added #########################"

echo "Removing old debug info";
rm -rf /tmp/DBGINFO* 2> /dev/null

echo "Collecting debug info";
dbginfo.sh

sleep 2

echo "List debug infos";
ls /tmp/DBGINFO* -Ud
assert_warn $? 0 "dbginfo.sh collected debug info";


echo "Extracting debug info";
assert_exec 0 tar -xf /tmp/DBGINFO*tgz

if [[ -e "$(echo DBGINFO*/sysfs.tgz)" ]]; then
	echo "Extracting sysfs.tgz";
	assert_exec 0 tar -C DBGINFO* -xzf DBGINFO*/sysfs.tgz
elif [[ ! -d "$(echo DBGINFO*/sys)" ]]; then
	assert_warn 1 0 "Missing 'sys' in DBGINFO directory";
fi

sleep 2

assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf $adapter -f  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf $adapter --force  >> results.log"

assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i REC $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i HBA $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i SAN $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -i MULTIPATH $adapter  >> results.log"

assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include REC $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include HBA $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include SAN $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --include MULTIPATH $adapter  >> results.log"


assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x REC $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x HBA $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x SAN $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -x MULTIPATH $adapter  >> results.log"


assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude REC $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude HBA $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude SAN $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --exclude MULTIPATH $adapter  >> results.log"

assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -z $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --zfcp-only $adapter  >> results.log"


assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -e $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --def-error $adapter  >> results.log"

assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -t 5 $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --timediff=5 $adapter  >> results.log"

assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf -r / $adapter  >> results.log"
assert_exec 0  "$tool_path -p DBGINFO*/sys/kernel/debug/s390dbf --root=/ $adapter  >> results.log"

############long option##################

assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf $adapter -f  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf $adapter --force  >> results.log"

assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i REC $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i HBA $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i SAN $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -i MULTIPATH $adapter  >> results.log"

assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include REC $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include HBA $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include SAN $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --include MULTIPATH $adapter  >> results.log"


assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x REC $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x HBA $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x SAN $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -x MULTIPATH $adapter  >> results.log"


assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude REC $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude HBA $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude SAN $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude SCSI $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude QDIO $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude QDIO_SETUP $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude QDIO_ERROR $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude CIO_TRACE $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude CIO_MSG $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude CIO_CRW $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude KERNEL $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --exclude MULTIPATH $adapter  >> results.log"

assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -z $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --zfcp-only $adapter  >> results.log"


assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -e $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --def-error $adapter  >> results.log"

assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -t 5 $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --timediff=5 $adapter  >> results.log"

assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf -r / $adapter  >> results.log"
assert_exec 0  "$tool_path --path DBGINFO*/sys/kernel/debug/s390dbf --root=/ $adapter  >> results.log"

#Cleaning up DBGINFO logs
rm -rf /tmp/DBGINFO*
rm -rf DBGINFO*

show_test_results
