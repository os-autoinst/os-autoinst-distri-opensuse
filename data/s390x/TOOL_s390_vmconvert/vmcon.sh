# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
RECORD=""
KERNEL_LEVEL="$(uname -r)";
VMLINUX_DBG="/usr/lib/debug/boot/vmlinux-$(uname -r).debug" # the vmlinux.debug
VMLINUX_BOOT="/boot/vmlinux-$(uname -r)" # the vmlinux file you find in /boot ....

for f in lib/*.sh; do source $f; done
source ./vmcon_1.sh || exit 1

if (isSles); then
  VMLINUX_DBG="/usr/lib/debug/boot/vmlinux-$(uname -r).debug" # the vmlinux.debug
  VMLINUX_BOOT="/boot/vmlinux-$(uname -r).gz" # the vmlinux file you find in /boot ....

fi


# Start
################################################################################

section_start "Creating vm dump and converting with vmconvert"

cleanup
createvmdump

# seek for the appropriate record no.
RECORD="$(vmur li | grep DMP |  awk '{print $2}')"
vmur rec $RECORD -f /root/vmdump.dmp
RET=$?
assert_warn 0 $RET "Copy the dump to the Linux file system"
if [ $RET != 0 ]; then
	cleanup;
	section_end;
	exit 1;
fi

ls /root/vmdump.dmp
RET=$?
assert_warn 0 $RET "The vmdump file has been moved into the Linux file system"
if [ $RET != 0 ]; then
	cleanup;
	section_end;
	exit 1;
fi

vmconvert -f /root/vmdump.dmp -o /root/converted_dump.lkcd 2> /dev/null
assert_warn 0 $RET "Perform vmconvert"
if [ $RET != 0 ]; then
	cleanup;
	section_end;
	exit 1;
fi

checkdump

section_end

section_start "Creating a vmdump and converting it with vmur -c"
cleanup
createvmdump

# seek for record no
RECORD="$(vmur li | grep DMP |  awk '{print $2}' | tail -n1)"
vmur rec $RECORD -c -f /root/converted_dump.lkcd
RET=$?
assert_warn 0 $RET "Copy vmdump to the Linux fs and converting it to the lkcd dump format with vmur -c"
if [ $RET != 0 ]; then
	cleanup;
	section_end;
	exit 1;
fi

ls /root/converted_dump.lkcd
RET=$?
assert_warn 0 $RET "The vmur -c converted lkcd dump file is available"
if [ $RET != 0 ]; then
	cleanup;
	section_end;
	exit 1;
fi

checkdump

vmconvert -v
RET=$?
assert_warn 0 $RET "Calling vmconvert -v"
if [ $RET != 0 ]; then
	cleanup;
	section_end;
	exit 1;
fi

# vmconvert -h
if [ "$(vmconvert -h | grep -c "Convert a vmdump into a lkcd")" -gt 0 ]; then
        assert_warn 0 0 "Calling the help function of vmconvert, proof that it listed at least something ..."
	else
        assert_warn 0 1 "Failed calling vmconvert -h"
        cleanup;
	section_end;
	exit 1;
fi

section_end

section_start "Error situations"

if (isSles); then
  if (isSles15); then
    vmconvert -f /dev/mem | grep "Operation not permitted"
  elif (isSles12); then
    vmconvert -f /dev/mem | grep "Operation not permitted"
  else # sles11
    vmconvert -f /dev/mem | grep "is not a vmdump"
  fi
else
  vmconvert -f /dev/mem | grep "Operation not permitted"
fi
RET=$?
assert_warn 0 $RET "Calling vmconvert with an input file which is not in vmdump format or not permitted"
if [ $RET != 0 ]; then
	cleanup;
	section_end;
	exit 1;
fi

vmconvert -f /root/not.there | grep "No such file or directory"
RET=$?
assert_warn 0 $RET "Calling vmconvert with an input file which is just not there"
if [ $RET != 0 ]; then
	cleanup;
	section_end;
	exit 1;
fi

vmconvert -X
RET=$?
if [ $RET -eq 1 ]; then
	assert_warn 0 0 "Calling vmconvert with an invalid option"
else
	assert_warn 0 1 "Calling vmconvert with an invalid option"
	cleanup;
	section_end;
	exit 1;
fi

vmconvert
RET=$?
if [ $RET -eq 1 ]; then
        assert_warn 0 0 "Calling vmconvert with an invalid option"
else
        assert_warn 0 1 "Calling vmconvert with an invalid option"
        cleanup;
	section_end;
	exit 1;
fi

cleanup
section_end
exit 0
