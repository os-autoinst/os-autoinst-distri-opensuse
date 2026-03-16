# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: update-bootloader
# Summary: Basic functional test for pbl package
# Maintainer: QE Core <qe-core@suse.de>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use package_utils;
use power_action_utils 'power_action';
use version_utils qw(is_sle is_leap is_sle_micro is_leap_micro check_version is_transactional);
use Utils::Backends 'is_pvm';
use Utils::Logging qw(record_avc_selinux_alerts);
use transactional;

sub run {
    my ($self) = @_;
    # https://progress.opensuse.org/issues/165686
    # package name is now 'update-bootloader', it will remain 'perl-Bootloader' for older products
    my $package = (!is_sle("<=15-SP7") && !is_leap("<=15.6") && !is_sle_micro("<=6.1") && !is_leap_micro("<=6.1")) ? 'update-bootloader' : 'perl-Bootloader';
    select_serial_terminal;

    if (script_run "rpm -q $package") {
        install_package "$package";
    }

    # version older than 1.1 does not support option default-settings
    my $pbl_version = script_output("rpm -q --qf '%{version}' $package");
    my $new_pbl = check_version('>=1.1', $pbl_version);

    # pbl --loader is not available on <15-SP3
    unless (is_sle("<15-SP3")) {
        if (get_var('UEFI')) {
            assert_script_run 'pbl --loader grub2-efi';
            validate_script_output 'cat /etc/sysconfig/bootloader', qr/LOADER_TYPE="grub2-efi"/;
        }
        else {
            assert_script_run 'pbl --loader grub2';
            validate_script_output 'cat /etc/sysconfig/bootloader', qr/LOADER_TYPE="grub2"/;
        }
    }

    if (is_transactional) {
        # this runs pbl internally and prepares an new snapshot
        trup_call "bootloader";

        if (!script_run('command -v fdectl') && get_var('QEMUTPM', 0) && !(get_var('FLAVOR', '') =~ /updates/i)) {
            # in order to avoid LUKS partition prompt, copy the blob into proper EFI dirs
            assert_script_run 'EFIDIR=$(dirname $(find /boot/efi/ -name "grub*.efi" -print -o -type d -name "BOOT" -prune))';
            assert_script_run 'test -z ${EFIDIR} || fdectl tpm-activate --uefi-boot-dir ${EFIDIR}';
        }

        check_reboot_changes;
        assert_script_run 'pbl --show';

    }
    else {
        assert_script_run 'pbl --install';
        assert_script_run 'pbl --config';
        power_action('reboot', textmode => 1);
        $self->wait_boot(bootloader_time => get_var('BOOTLOADER_TIMEOUT', 300));
        select_serial_terminal;
    }

    # Add new option and check if it exists
    assert_script_run 'pbl --add-option TEST_OPTION="test_value"';
    validate_script_output 'cat /etc/default/grub', qr/test_value/;

    # Delete option and check if it was deleted
    assert_script_run 'pbl --del-option "TEST_OPTION"';
    assert_script_run('! grep -q "TEST_OPTION" /etc/default/grub');

    # Add new option and check if it's logged in new log file
    assert_script_run 'pbl --log /var/log/pbl-test.log --add-option LOG_OPTION="log_value"';
    validate_script_output 'cat /var/log/pbl-test.log', qr/log_value/;

    if ($new_pbl) {
        validate_script_output 'pbl --default-settings', qr/kernel|initrd|append/;
    }
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(bootloader_time => get_var('BOOTLOADER_TIMEOUT', 300));
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_logs('/var/log/pbl.log');
}

sub post_run_hook {
    select_console('log-console');
    shift->record_avc_selinux_alerts;
}

1;
