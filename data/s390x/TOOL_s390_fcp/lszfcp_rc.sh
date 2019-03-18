# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash
# set -x

for i in `ls lib/*.sh`; do source $i || exit 8; done


adapter=$1
wwpn=$2
lun=$3

tool_path=$(s390_get_tool_path lszfcp)

init_tests

start_section 0 "TOOL:lszfcp test"

assert_exec 0 $tool_path -h
assert_exec 0 $tool_path --help
assert_exec 0 $tool_path -v
assert_exec 0 $tool_path -V
assert_exec 0 $tool_path --version
assert_exec 0 $tool_path -H
assert_exec 0 $tool_path --hosts
assert_exec 0 $tool_path -P
assert_exec 0 $tool_path --ports
assert_exec 0 $tool_path -D
assert_exec 0 $tool_path --devices
assert_exec 0 $tool_path -a
assert_exec 0 $tool_path -P -H -D
assert_exec 0 $tool_path -b $adapter
assert_exec 0 $tool_path -p $wwpn
assert_exec 0 $tool_path -l $lun
assert_exec 0 $tool_path --busid $adapter
assert_exec 0 $tool_path --wwpn $wwpn
assert_exec 0 $tool_path --lun $lun
assert_exec 0 $tool_path -b $adapter -p $wwpn
assert_exec 0 $tool_path -b $adapter -p $wwpn -l $lun
assert_exec 0 $tool_path --busid $adapter --wwpn $wwpn
assert_exec 0 $tool_path --busid $adapter --wwpn $wwpn --lun $lun
assert_exec 0 $tool_path -s /sys
assert_exec 0 $tool_path --sysfs=/sys
assert_exec 1 $tool_path --sysfs=/mnt
assert_exec 1 $tool_path --sysfs=/mnt

assert_exec 0 $tool_path -X
assert_exec 0 $tool_path -l xxxx
assert_exec 0 $tool_path -p yyyy
assert_exec 0 $tool_path -b mmmm


end_section 0
show_test_results
