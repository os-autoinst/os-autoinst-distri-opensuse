# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Ship the "swtpm" software TPM emulator for QEMU,
#          install required packages and download the pre-installed
#          OS images for later tests, prepare a script for remote
#          ssh login and execution
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81256, tc#1768671, poo#100512

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use Utils::Architectures;
use rpi 'enable_tpm_slb9670';
use version_utils 'is_sle';

sub run {
    # Enable TPM on Raspberry Pi 4
    # Refer: https://en.opensuse.org/HCL:Raspberry_Pi3_TPM
    if (get_var('MACHINE') =~ /RPi4/) {
        enable_tpm_slb9670;
    } else {
        select_serial_terminal;
    }

    zypper_call("in qemu swtpm virt-install wget gnutls libvirt-daemon");
    zypper_call("in libvirt virt-manager") if is_sle('<16');
    zypper_call("in -t pattern kvm_server") if is_sle('>=16');

    assert_script_run("systemctl start libvirtd");
    assert_script_run("virsh net-start default");
    assert_script_run("systemctl is-active libvirtd");
    assert_script_run("virsh net-list | grep default | grep active");

    # Define image paths
    my $image_path = '/var/lib/libvirt/images';
    my $hdd_swtpm = get_required_var('HDD_2');
    my $legacy_image = 'swtpm_legacy@64bit.qcow2';
    my $uefi_image = 'swtpm_uefi@64bit.qcow2';

    # Download the pre-installed guest image with retries
    my $attempts = 10;
    while ($attempts--) {
        last unless script_run("wget -c -P $image_path " . autoinst_url("/assets/hdd/$hdd_swtpm"), 900);
        sleep 60;
    }
    die "Failed to download: $image_path/" . autoinst_url("/assets/hdd/$hdd_swtpm") unless $attempts;

    # Determine sample file based on UEFI support
    my $sample_file = 'swtpm/swtpm_' . (check_var('UEFI', '1') ? ('uefi' . (is_aarch64 ? '_aarch64' : '') . '.xml') : 'legacy.xml');
    my $final_image = check_var('UEFI', '1') ? $uefi_image : $legacy_image;

    assert_script_run("mv $image_path/$hdd_swtpm $image_path/$final_image");
    assert_script_run("wget --quiet " . data_url($sample_file) . " -P $image_path");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
