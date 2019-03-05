# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

source lib/auxx.sh || exit 1
source lib/env.sh || exit 1

echo  "mount debugfs"
umount /sys/kernel/debug > /dev/null 2>&1
ls /sys/kernel/debug >> /dev/null 2>&1
assert_fail $? 0 "check whether sysfs entry for debugfs is created or not"
sleep 1
mount none -t debugfs /sys/kernel/debug >> /dev/null 2>&1
mount | grep debugfs >> /dev/null  2>&1
