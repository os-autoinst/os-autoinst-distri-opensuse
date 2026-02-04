# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot from disk and login into MicroOS
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use base "consoletest";
use testapi;
use main_micro_alp;
use version_utils qw(is_sle_micro);
use Utils::Architectures qw(is_aarch64);
use microos "microos_login";
use transactional "record_kernel_audit_messages";
use utils qw(is_uefi_boot);

sub run {
    # default timeout in grub2 is set to 10s
    # Sometimes, machines tend to stall when trying to match grub2
    # this leads to test failures because openQA does not assert grub2 properly
    # KEEP_GRUB_TIMEOUT=0 will force the grub needle to match, useful when booting
    # pre-configured images with disabled timeout. See opensusebasetest::handle_grub
    if ((is_uefi_boot || is_aarch64 || get_var('OFW') || is_sle_micro('>=6.0')) && get_var('KEEP_GRUB_TIMEOUT', '1') && !main_micro_alp::is_dvd()) {
        shift->wait_boot_past_bootloader(textmode => 1);
    } else {
        shift->wait_boot(bootloader_time => 300);
    }
    microos_login;
    # Avoid uploading logs in multimachine tests as no ip address is currently assigned to the interface
    record_kernel_audit_messages(log_upload => 1) unless (get_var('NICTYPE') eq 'tap');
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
