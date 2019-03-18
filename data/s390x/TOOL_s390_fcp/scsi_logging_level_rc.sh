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

tool_path=$(s390_get_tool_path scsi_logging_level)

init_tests

start_section 0 "TOOL:scsi_logging_level test"

assert_exec 1 $tool_path
assert_exec 0 $tool_path -h
assert_exec 0 $tool_path -v
assert_exec 0 $tool_path -g
assert_exec 0 $tool_path -s -a 0
assert_exec 0 $tool_path -s --all 0
assert_exec 0 $tool_path -s -E 0
assert_exec 0 $tool_path -s --error 0
assert_exec 0 $tool_path -s -T 0
assert_exec 0 $tool_path -s --timeout 0
assert_exec 0 $tool_path -s -S 0
assert_exec 0 $tool_path -s --scan 0
assert_exec 0 $tool_path -s -M 0
assert_exec 0 $tool_path -s --midlevel 0
assert_exec 0 $tool_path -s --mlqueue 0
assert_exec 0 $tool_path -s --mlcomplete 0
assert_exec 0 $tool_path -s -L 0
assert_exec 0 $tool_path -s --lowlevel 0
assert_exec 0 $tool_path -s --llqueue 0
assert_exec 0 $tool_path -s --llcomplete 0
assert_exec 0 $tool_path -s -H 0
assert_exec 0 $tool_path -s --highlevel 0
assert_exec 0 $tool_path -s --hlqueue 0
assert_exec 0 $tool_path -s --hlcomplete 0
assert_exec 0 $tool_path -s -I 0
assert_exec 0 $tool_path -s --ioctl 0
assert_exec 0 $tool_path -s -a 1
assert_exec 0 $tool_path -s --all 1
assert_exec 0 $tool_path -s -E 1
assert_exec 0 $tool_path -s --error 1
assert_exec 0 $tool_path -s -T 1
assert_exec 0 $tool_path -s --timeout 1
assert_exec 0 $tool_path -s -S 1
assert_exec 0 $tool_path -s --scan 1
assert_exec 0 $tool_path -s -M 1
assert_exec 0 $tool_path -s --midlevel 1
assert_exec 0 $tool_path -s --mlqueue 1
assert_exec 0 $tool_path -s --mlcomplete 1
assert_exec 0 $tool_path -s -L 1
assert_exec 0 $tool_path -s --lowlevel 1
assert_exec 0 $tool_path -s --llqueue 1
assert_exec 0 $tool_path -s --llcomplete 1
assert_exec 0 $tool_path -s -H 1
assert_exec 0 $tool_path -s --highlevel 1
assert_exec 0 $tool_path -s --hlqueue 1
assert_exec 0 $tool_path -s --hlcomplete 1
assert_exec 0 $tool_path -s -I 1
assert_exec 0 $tool_path -s --ioctl 1
assert_exec 0 $tool_path -s -a 2
assert_exec 0 $tool_path -s --all 2
assert_exec 0 $tool_path -s -E 2
assert_exec 0 $tool_path -s --error 2
assert_exec 0 $tool_path -s -T 2
assert_exec 0 $tool_path -s --timeout 2
assert_exec 0 $tool_path -s -S 2
assert_exec 0 $tool_path -s --scan 2
assert_exec 0 $tool_path -s -M 2
assert_exec 0 $tool_path -s --midlevel 2
assert_exec 0 $tool_path -s --mlqueue 2
assert_exec 0 $tool_path -s --mlcomplete 2
assert_exec 0 $tool_path -s -L 2
assert_exec 0 $tool_path -s --lowlevel 2
assert_exec 0 $tool_path -s --llqueue 2
assert_exec 0 $tool_path -s --llcomplete 2
assert_exec 0 $tool_path -s -H 2
assert_exec 0 $tool_path -s --highlevel 2
assert_exec 0 $tool_path -s --hlqueue 2
assert_exec 0 $tool_path -s --hlcomplete 2
assert_exec 0 $tool_path -s -I 2
assert_exec 0 $tool_path -s --ioctl 2
assert_exec 0 $tool_path -s -a 3
assert_exec 0 $tool_path -s --all 3
assert_exec 0 $tool_path -s -E 3
assert_exec 0 $tool_path -s --error 3
assert_exec 0 $tool_path -s -T 3
assert_exec 0 $tool_path -s --timeout 3
assert_exec 0 $tool_path -s -S 3
assert_exec 0 $tool_path -s --scan 3
assert_exec 0 $tool_path -s -M 3
assert_exec 0 $tool_path -s --midlevel 3
assert_exec 0 $tool_path -s --mlqueue 3
assert_exec 0 $tool_path -s --mlcomplete 3
assert_exec 0 $tool_path -s -L 3
assert_exec 0 $tool_path -s --lowlevel 3
assert_exec 0 $tool_path -s --llqueue 3
assert_exec 0 $tool_path -s --llcomplete 3
assert_exec 0 $tool_path -s -H 3
assert_exec 0 $tool_path -s --highlevel 3
assert_exec 0 $tool_path -s --hlqueue 3
assert_exec 0 $tool_path -s --hlcomplete 3
assert_exec 0 $tool_path -s -I 3
assert_exec 0 $tool_path -s --ioctl 3
assert_exec 0 $tool_path -s -a 4
assert_exec 0 $tool_path -s --all 4
assert_exec 0 $tool_path -s -E 4
assert_exec 0 $tool_path -s --error 4
assert_exec 0 $tool_path -s -T 4
assert_exec 0 $tool_path -s --timeout 4
assert_exec 0 $tool_path -s -S 4
assert_exec 0 $tool_path -s --scan 4
assert_exec 0 $tool_path -s -M 4
assert_exec 0 $tool_path -s --midlevel 4
assert_exec 0 $tool_path -s --mlqueue 4
assert_exec 0 $tool_path -s --mlcomplete 4
assert_exec 0 $tool_path -s -L 4
assert_exec 0 $tool_path -s --lowlevel 4
assert_exec 0 $tool_path -s --llqueue 4
assert_exec 0 $tool_path -s --llcomplete 4
assert_exec 0 $tool_path -s -H 4
assert_exec 0 $tool_path -s --highlevel 4
assert_exec 0 $tool_path -s --hlqueue 4
assert_exec 0 $tool_path -s --hlcomplete 4
assert_exec 0 $tool_path -s -I 4
assert_exec 0 $tool_path -s --ioctl 4
assert_exec 0 $tool_path -s -a 5
assert_exec 0 $tool_path -s --all 5
assert_exec 0 $tool_path -s -E 5
assert_exec 0 $tool_path -s --error 5
assert_exec 0 $tool_path -s -T 5
assert_exec 0 $tool_path -s --timeout 5
assert_exec 0 $tool_path -s -S 5
assert_exec 0 $tool_path -s --scan 5
assert_exec 0 $tool_path -s -M 5
assert_exec 0 $tool_path -s --midlevel 5
assert_exec 0 $tool_path -s --mlqueue 5
assert_exec 0 $tool_path -s --mlcomplete 5
assert_exec 0 $tool_path -s -L 5
assert_exec 0 $tool_path -s --lowlevel 5
assert_exec 0 $tool_path -s --llqueue 5
assert_exec 0 $tool_path -s --llcomplete 5
assert_exec 0 $tool_path -s -H 5
assert_exec 0 $tool_path -s --highlevel 5
assert_exec 0 $tool_path -s --hlqueue 5
assert_exec 0 $tool_path -s --hlcomplete 5
assert_exec 0 $tool_path -s -I 5
assert_exec 0 $tool_path -s --ioctl 5
assert_exec 0 $tool_path -s -a 6
assert_exec 0 $tool_path -s --all 6
assert_exec 0 $tool_path -s -E 6
assert_exec 0 $tool_path -s --error 6
assert_exec 0 $tool_path -s -T 6
assert_exec 0 $tool_path -s --timeout 6
assert_exec 0 $tool_path -s -S 6
assert_exec 0 $tool_path -s --scan 6
assert_exec 0 $tool_path -s -M 6
assert_exec 0 $tool_path -s --midlevel 6
assert_exec 0 $tool_path -s --mlqueue 6
assert_exec 0 $tool_path -s --mlcomplete 6
assert_exec 0 $tool_path -s -L 6
assert_exec 0 $tool_path -s --lowlevel 6
assert_exec 0 $tool_path -s --llqueue 6
assert_exec 0 $tool_path -s --llcomplete 6
assert_exec 0 $tool_path -s -H 6
assert_exec 0 $tool_path -s --highlevel 6
assert_exec 0 $tool_path -s --hlqueue 6
assert_exec 0 $tool_path -s --hlcomplete 6
assert_exec 0 $tool_path -s -I 6
assert_exec 0 $tool_path -s --ioctl 6
assert_exec 0 $tool_path -s -a 7
assert_exec 0 $tool_path -s --all 7
assert_exec 0 $tool_path -s -E 7
assert_exec 0 $tool_path -s --error 7
assert_exec 0 $tool_path -s -T 7
assert_exec 0 $tool_path -s --timeout 7
assert_exec 0 $tool_path -s -S 7
assert_exec 0 $tool_path -s --scan 7
assert_exec 0 $tool_path -s -M 7
assert_exec 0 $tool_path -s --midlevel 7
assert_exec 0 $tool_path -s --mlqueue 7
assert_exec 0 $tool_path -s --mlcomplete 7
assert_exec 0 $tool_path -s -L 7
assert_exec 0 $tool_path -s --lowlevel 7
assert_exec 0 $tool_path -s --llqueue 7
assert_exec 0 $tool_path -s --llcomplete 7
assert_exec 0 $tool_path -s -H 7
assert_exec 0 $tool_path -s --highlevel 7
assert_exec 0 $tool_path -s --hlqueue 7
assert_exec 0 $tool_path -s --hlcomplete 7
assert_exec 0 $tool_path -s -I 7
assert_exec 0 $tool_path -s --ioctl 7
assert_exec 0 $tool_path -c -a 0
assert_exec 0 $tool_path -c --all 0
assert_exec 0 $tool_path -c -E 0
assert_exec 0 $tool_path -c --error 0
assert_exec 0 $tool_path -c -T 0
assert_exec 0 $tool_path -c --timeout 0
assert_exec 0 $tool_path -c -S 0
assert_exec 0 $tool_path -c --scan 0
assert_exec 0 $tool_path -c -M 0
assert_exec 0 $tool_path -c --midlevel 0
assert_exec 0 $tool_path -c --mlqueue 0
assert_exec 0 $tool_path -c --mlcomplete 0
assert_exec 0 $tool_path -c -L 0
assert_exec 0 $tool_path -c --lowlevel 0
assert_exec 0 $tool_path -c --llqueue 0
assert_exec 0 $tool_path -c --llcomplete 0
assert_exec 0 $tool_path -c -H 0
assert_exec 0 $tool_path -c --highlevel 0
assert_exec 0 $tool_path -c --hlqueue 0
assert_exec 0 $tool_path -c --hlcomplete 0
assert_exec 0 $tool_path -c -I 0
assert_exec 0 $tool_path -c --ioctl 0
assert_exec 0 $tool_path -c -a 1
assert_exec 0 $tool_path -c --all 1
assert_exec 0 $tool_path -c -E 1
assert_exec 0 $tool_path -c --error 1
assert_exec 0 $tool_path -c -T 1
assert_exec 0 $tool_path -c --timeout 1
assert_exec 0 $tool_path -c -S 1
assert_exec 0 $tool_path -c --scan 1
assert_exec 0 $tool_path -c -M 1
assert_exec 0 $tool_path -c --midlevel 1
assert_exec 0 $tool_path -c --mlqueue 1
assert_exec 0 $tool_path -c --mlcomplete 1
assert_exec 0 $tool_path -c -L 1
assert_exec 0 $tool_path -c --lowlevel 1
assert_exec 0 $tool_path -c --llqueue 1
assert_exec 0 $tool_path -c --llcomplete 1
assert_exec 0 $tool_path -c -H 1
assert_exec 0 $tool_path -c --highlevel 1
assert_exec 0 $tool_path -c --hlqueue 1
assert_exec 0 $tool_path -c --hlcomplete 1
assert_exec 0 $tool_path -c -I 1
assert_exec 0 $tool_path -c --ioctl 1
assert_exec 0 $tool_path -c -a 2
assert_exec 0 $tool_path -c --all 2
assert_exec 0 $tool_path -c -E 2
assert_exec 0 $tool_path -c --error 2
assert_exec 0 $tool_path -c -T 2
assert_exec 0 $tool_path -c --timeout 2
assert_exec 0 $tool_path -c -S 2
assert_exec 0 $tool_path -c --scan 2
assert_exec 0 $tool_path -c -M 2
assert_exec 0 $tool_path -c --midlevel 2
assert_exec 0 $tool_path -c --mlqueue 2
assert_exec 0 $tool_path -c --mlcomplete 2
assert_exec 0 $tool_path -c -L 2
assert_exec 0 $tool_path -c --lowlevel 2
assert_exec 0 $tool_path -c --llqueue 2
assert_exec 0 $tool_path -c --llcomplete 2
assert_exec 0 $tool_path -c -H 2
assert_exec 0 $tool_path -c --highlevel 2
assert_exec 0 $tool_path -c --hlqueue 2
assert_exec 0 $tool_path -c --hlcomplete 2
assert_exec 0 $tool_path -c -I 2
assert_exec 0 $tool_path -c --ioctl 2
assert_exec 0 $tool_path -c -a 3
assert_exec 0 $tool_path -c --all 3
assert_exec 0 $tool_path -c -E 3
assert_exec 0 $tool_path -c --error 3
assert_exec 0 $tool_path -c -T 3
assert_exec 0 $tool_path -c --timeout 3
assert_exec 0 $tool_path -c -S 3
assert_exec 0 $tool_path -c --scan 3
assert_exec 0 $tool_path -c -M 3
./scsi_logging_level_rc_1.sh

end_section 0
show_test_results
