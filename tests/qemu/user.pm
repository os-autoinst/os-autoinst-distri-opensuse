# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run QEMU user mode
# Maintainer: Dominik Heidler <dheidler@suse.de>

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
