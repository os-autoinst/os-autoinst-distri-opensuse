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

    assert_screen 'selfinstall-screen', 180;
    send_key 'down' unless check_screen 'selfinstall-select-drive';
    assert_screen 'selfinstall-select-drive';
    send_key 'ret';
    assert_screen 'slem-selfinstall-overwrite-drive';
    send_key 'ret';

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
        microos_login;
    } else {
        microos_login;
        # The installed system is definitely up now, so the CD can be ejected
        eject_cd() unless ($no_cd || is_usb_boot);
    }

    # Remove usb boot entry and empty usb disks to ensure installed system boots from hard disk
    if (is_ipmi and is_uefi_boot and is_usb_boot) {
        remove_efiboot_entry(boot_entry => 'OpenQA-added-UEFI-USB-BOOT');
        empty_usb_disks;
        ipmitool("chassis bootdev disk options=persistent,efiboot") for (0 .. 2);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
