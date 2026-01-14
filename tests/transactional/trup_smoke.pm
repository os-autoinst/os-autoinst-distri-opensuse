# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic smoke test to verify all basic transactional update
#           operations work and system can properly boot.
# Maintainer: qa-c team <qa-c@suse.de>

use base "consoletest";
use testapi;
use transactional;
use Utils::Architectures qw(is_s390x);
use version_utils qw(is_bootloader_sdboot is_sle_micro is_bootloader_grub2_bls);
use serial_terminal;

sub action {
    my ($target, $text, $reboot) = @_;
    $reboot //= 1;
    record_info('TEST', $text);
    trup_call($target);

    if ($target =~ /bootloader/ && get_var('FLAVOR') =~ m/-encrypted/i) {
        record_soft_failure("Workaround for bsc#1228126");
        script_run("fdectl tpm-authorize");
    }

    check_reboot_changes($reboot);
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    action('bootloader', 'Reinstall bootloader');
    action('grub.cfg', 'Regenerate grub.cfg');
    action('initrd', 'Regenerate initrd');
    if (is_bootloader_sdboot || is_bootloader_grub2_bls) {
        record_soft_failure("boo#1226676: kdump not yet implemented with sdbootutil");
    }
    else {
        action('kdump', 'Regenerate kdump') if is_sle_micro;
    }
    action('cleanup', 'Run cleanup', 0);
}

1;
