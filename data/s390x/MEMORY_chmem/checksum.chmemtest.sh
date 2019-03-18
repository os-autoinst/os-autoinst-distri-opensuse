# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
RUNTIME=$1                # Runtime in minutes
FILESZ=$2                 # Filesize in MB - resommended 524
# Create a test file according to above values
# FILESZ=$2     # Filesize in MB - resommended 524
BS=1024M        # Buffersize - recommended 524M

START_TIME=`date '+%s'`
[ -z $RUNTIME ] && RUNTIME=60
[ -z $FILESZ ]  && FILESZ=256

for f in lib/*.sh; do source $f; done

start_section 0 "file copy with md5sum for chmem"

init_tests

rm -rf /tmp/chmemtest.bin /tmp/chmemtest1.bin &> /dev/null

dd if=/dev/urandom of=/tmp/chmemtest.bin bs=1M count=$FILESZ
CHECKSUM=`md5sum -b /tmp/chmemtest.bin | awk '{print $1}'`
# echo md5sum of file is $CHECKSUM

while [ `date '+%s'` -lt `expr 60 \* $RUNTIME + $START_TIME` ]; do

	dd if=/tmp/chmemtest.bin of=/tmp/chmemtest1.bin bs=$BS
	if [ "$CHECKSUM" != `md5sum -b /tmp/chmemtest1.bin  | awk '{print $1}'` ]; then
		assert_warn 0 1 "Checksum was not identical"
		end_section 0
		exit 1
	fi
	sleep 20
	rm /tmp/chmemtest.bin

	dd if=/tmp/chmemtest1.bin of=/tmp/chmemtest.bin bs=$BS
	if [ "$CHECKSUM" != `md5sum -b /tmp/chmemtest.bin  | awk '{print $1}'` ]; then
		assert_warn 0 1 "Checksum was not identical"
		end_section 0
		exit 1
	fi
	sleep 20
	rm /tmp/chmemtest1.bin
done

rm /tmp/chmemtest.bin
assert_warn 0 0 "Copying with checksum validation ended successfully"

# Display the Summary
show_test_results

end_section 0
