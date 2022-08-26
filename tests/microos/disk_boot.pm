# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot from disk and login into MicroOS
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle_micro);
use Utils::Architectures qw(is_aarch64);
use microos "microos_login";

sub run {

    # default timeout in grub2 is set to 10s
    # osd's arm machines tend to stall when trying to match grub2
    # this leads to test failures because openQA does not assert grub2 properly
    if (is_sle_micro && is_aarch64 && get_var('BOOT_HDD_IMAGE')) {
        shift->wait_boot_past_bootloader(textmode => 1, ready_time => 300);
    } else {
        shift->wait_boot(bootloader_time => 300);
    }
    microos_login;
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
