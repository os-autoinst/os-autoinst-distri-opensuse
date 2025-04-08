# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Boot from disk
# Maintainer: Santiago Zarate <santiago.zarate@suse.com>

use base "bootbasetest";
use strict;
use warnings;
use testapi;


sub run {
    shift->wait_boot(bootloader_time => 300);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    assert_screen 'emergency-mode';
    send_key 'ret';
    enter_cmd "echo '##### initramfs logs #####'> /dev/$serialdev";
    script_run "cat /run/initramfs/rdsosreport.txt > /dev/$serialdev ";
    enter_cmd "echo '##### END #####'> /dev/$serialdev";
}

1;
