# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: dm crypt -> add flags to optionally bypass kcryptd
#          workqueues, the options are 'no_read_workqueue' and
#          'no_write_workqueue'
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#88873, tc#1768663

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use version_utils 'is_sle';

sub run {
    my $self = shift;
    select_serial_terminal;

    # Install runtime dependencies
    zypper_call("in sudo");

    # Make sure the code changes are there
    if (is_sle) {
        assert_script_run("rpm -q kernel-default --changelog | grep 'dm crypt' | grep 'kcryptd workqueues'");
    }

    # Simulate a ram device
    assert_script_run("modprobe brd rd_nr=1 rd_size=512000");

    # Create dm-crypt devices upon the ram device with different flags
    my $inline_r_dev = 'eram0-inline-read';
    my $inline_w_dev = 'eram0-inline-write';
    assert_script_run("echo '0 1024000 crypt capi:ecb(cipher_null) - 0 /dev/ram0 0 1 no_write_workqueue' | sudo dmsetup create $inline_w_dev");
    assert_script_run("echo '0 1024000 crypt capi:ecb(cipher_null) - 0 /dev/ram0 0 1 no_read_workqueue' | sudo dmsetup create $inline_r_dev");

    # Check the flags are set correctly
    assert_script_run("dmsetup table /dev/mapper/$inline_w_dev | grep no_write_workqueue");
    assert_script_run("dmsetup table /dev/mapper/$inline_r_dev | grep no_read_workqueue");

    # Teardown and release the ram resource
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;

    # For aarch64 and ppc64le platforms, OS may need a bit more
    # time to boot up, so add some wait time here
    $self->wait_boot(textmode => 1, bootloader_time => 400, ready_time => 600);
    select_serial_terminal;
}

1;
