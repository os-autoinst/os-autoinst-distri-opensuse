# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot SelfInstallation image for SLEM
# Maintainer: QA-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use microos "microos_login";
use Utils::Architectures qw(is_aarch64);
use version_utils qw(is_leap_micro is_sle_micro);
use utils;
use Utils::Backends qw(is_ipmi);
use ipmi_backend_utils qw(ipmitool);

sub run {
    my ($self) = @_;

    unless (get_var('INSTALL_DISK_WWN')) {
        if (get_var('NUMDISKS') > 1) {
            assert_screen 'selfinstall-screen', 180;
            send_key 'down' unless check_screen 'selfinstall-select-drive';
            assert_screen 'selfinstall-select-drive';
            send_key 'ret';
        }
        assert_screen 'slem-selfinstall-overwrite-drive';
        send_key 'ret';
    }
    else {
        assert_screen('slem-selfinstall-write-drive', 350 / get_var('TIMEOUT_SCALE', 1));
        check_screen('slem-selfinstall-verify-drive', 350 / get_var('TIMEOUT_SCALE', 1));
    }

    my $no_cd;
    # workaround failed *kexec* execution on UEFI with SecureBoot
    if (get_var('UEFI') && is_sle_micro('<5.4') && assert_screen('failed-to-kexec', 240)) {
        record_soft_failure('bsc#1203896 - kexec fail in selfinstall with secureboot');
        send_key 'ret';
        eject_cd();
        $no_cd = 1;
    }

    # Before combustion 1.2, a reboot is necessary for firstboot configuration
    if (is_leap_micro('<6.0') || is_sle_micro('<6.0')) {
        wait_serial('reboot: Restarting system', 240) or die "SelfInstall image has not rebooted as expected";
        # Avoid booting into selfinstall again
        eject_cd() unless $no_cd;
        # Reboot again to avoid potential race conditions
        send_key 'ctrl-alt-delete' unless $no_cd;
        microos_login;
    } elsif (check_var('FIRST_BOOT_CONFIG', 'wizard')) {
        wait_serial('The initial configuration', 180) or die "jeos-firstboot has not been reached";
        eject_cd() unless ($no_cd || is_usb_boot);
        return 1;
    } else {
        microos_login;
        # The installed system is definitely up now, so the CD can be ejected
        eject_cd() unless ($no_cd || is_usb_boot || is_ipxe_with_disk_image);
    }

    # Remove usb boot entry and empty usb disks to ensure installed system boots from hard disk
    if (is_ipmi and is_uefi_boot and is_usb_boot) {
        remove_efiboot_entry(boot_entry => 'OpenQA-added-UEFI-USB-BOOT');
        empty_usb_disks;
        ipmitool("chassis bootdev disk options=persistent,efiboot") for (0 .. 2);
    }
}

sub post_run_hook {
    # The system will continue with jeos-firstboot
    # the console cannot be cleaned as we expect another dialog
    # instead of console or login prompt
    if (check_var('FIRST_BOOT_CONFIG', 'wizard')) {
        return 1;
    }

    shift->SUPER::post_run_hook();
}

sub test_flags {
    return {fatal => 1};
}

1;
