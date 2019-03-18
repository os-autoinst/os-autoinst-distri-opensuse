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

tool_path=$(s390_get_tool_path lsluns)

modprobe sg

init_tests

start_section 0  "TOOL:lsluns test"

assert_exec 0 $tool_path -h
assert_exec 0 $tool_path --help
assert_exec 0 $tool_path -v
assert_exec 0 $tool_path --version
assert_exec 0 $tool_path
assert_exec 0 $tool_path -a
assert_exec 0 $tool_path --active
assert_exec 0 $tool_path -c $adapter
assert_exec 0 $tool_path --ccw $adapter
assert_exec 0 $tool_path -p $wwpn
assert_exec 0 $tool_path --port $wwpn
assert_exec 1 $tool_path -x
assert_exec 0 $tool_path -c xxxx0000
assert_exec 0 $tool_path -p 0000xxxx


end_section 0
show_test_results
