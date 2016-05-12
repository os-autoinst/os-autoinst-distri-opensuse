# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "hacluster";
use strict;
use testapi;
use lockapi;

sub run() {
    script_run "echo softdog > /etc/modules-load.d/softdog.conf";
    script_run "systemctl restart systemd-modules-load.service";
    type_string "echo \"softdog=`lsmod | grep softdog | wc -l`\" > /dev/$serialdev\n";
    die "softdog module not loaded" unless wait_serial "softdog=1";
}

sub test_flags {
    return {fatal => 1};
}

1;
