#!/bin/sh -ex
echo "This is an AutoYaST post script test logfile" > /var/log/autoyast_post_script.log || exit 1
