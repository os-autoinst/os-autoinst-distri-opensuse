# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run QEMU user mode
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use transactional qw(trup_call check_reboot_changes);
use version_utils qw(is_transactional);

sub run {
    select_console 'root-console';

    if (is_transactional) {
        trup_call("pkg install qemu-linux-user");
        check_reboot_changes;
    } else {
        zypper_call("in qemu-linux-user");
    }
    # file is from https://busybox.net/downloads/binaries/1.21.1/busybox-sparc';
    assert_script_run 'curl --remote-name ' . data_url('busybox-sparc');
    assert_script_run 'chmod +x busybox-sparc';
    assert_script_run 'qemu-sparc busybox-sparc whoami';
}

1;
