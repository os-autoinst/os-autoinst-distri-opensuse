#! /bin/bash
set -x
echo "This is an AutoYaST init script test logfile" >/var/log/autoyast_init_script.log || exit 1
exit 0
