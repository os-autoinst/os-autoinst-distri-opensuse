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

tool_path=$(s390_get_tool_path lsscsi)

init_tests

start_section 0 "TOOL:lsscsi test"

assert_exec 0 $tool_path
assert_exec 0 $tool_path -h
assert_exec 0 $tool_path --help
assert_exec 0 $tool_path -V
assert_exec 0 $tool_path --verbose
assert_exec 0 $tool_path -v
assert_exec 0 $tool_path --version
assert_exec 0 $tool_path -c
assert_exec 0 $tool_path --classic
assert_exec 0 $tool_path -d
assert_exec 0 $tool_path --device
assert_exec 0 $tool_path -g
assert_exec 0 $tool_path --generic
assert_exec 0 $tool_path -H
assert_exec 0 $tool_path --hosts
assert_exec 0 $tool_path -k
assert_exec 0 $tool_path --kname
assert_exec 0 $tool_path -l
assert_exec 0 $tool_path --long
assert_exec 1 $tool_path --log

assert_exec 1 $tool_path --hots

assert_exec 0 $tool_path --list
assert_exec 0 $tool_path -L
assert_exec 0 $tool_path -p
assert_exec 0 $tool_path --protection
assert_exec 0 $tool_path -t
assert_exec 0 $tool_path --transport
assert_exec 0 $tool_path -y /sys
assert_exec 0 $tool_path --sysfsroot=/sys


end_section 0
show_test_results
