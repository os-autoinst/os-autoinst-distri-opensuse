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

sub run {
    if (get_var('MACHINE') =~ /RPi4/) {
        enable_tpm_slb9670;
    } else {
        select_serial_terminal;
    }


    # Enable TPM on Raspberry Pi 4
    # Refer: https://en.opensuse.org/HCL:Raspberry_Pi3_TPM
    enable_tpm_slb9670 if (get_var('MACHINE') =~ /RPi4/);

    # Install the required packages for libvirt environment setup
    zypper_call("in qemu libvirt swtpm virt-install virt-manager wget");

    # Start libvirtd daemon and start the default libvirt network
    assert_script_run("systemctl start libvirtd");
    assert_script_run("virsh net-start default");
    assert_script_run("systemctl is-active libvirtd");
    assert_script_run("virsh net-list | grep default | grep active");

    # Download the pre-installed guest images and sample xml files
    my $image_path = '/var/lib/libvirt/images';
    my $legacy_image = 'swtpm_legacy@64bit.qcow2';
    my $uefi_image = 'swtpm_uefi@64bit.qcow2';
    my $openqa_url = get_var('OPENQA_URL', autoinst_url);
    if (get_var('HDD_SWTPM_LEGACY')) {
        my $hdd_swtpm_legacy = get_required_var('HDD_SWTPM_LEGACY');
        my $sample_file = 'swtpm/swtpm_legacy.xml';
        # Since this randomly fails, we retry 10 times each time adding a delay before failing and exiting.
        my $times = 10;
        ($times-- && sleep 60) while (script_run("wget -c -P $image_path $openqa_url/assets/hdd/$hdd_swtpm_legacy", 900) != 0 && $times);
        die "Couldn't download $image_path $openqa_url/assets/hdd/$hdd_swtpm_legacy" unless $times;
        assert_script_run("mv $image_path/$hdd_swtpm_legacy $image_path/$legacy_image");
        assert_script_run("wget --quiet " . data_url($sample_file) . " -P $image_path");
    }
    elsif (get_var('HDD_SWTPM_UEFI')) {
        my $hdd_swtpm_uefi = get_required_var('HDD_SWTPM_UEFI');
        my $sample_file = 'swtpm/swtpm_uefi';
        $sample_file .= is_aarch64 ? '_aarch64.xml' : '.xml';
        assert_script_run("wget -c -P $image_path $openqa_url/assets/hdd/$hdd_swtpm_uefi", 900);
        assert_script_run("mv $image_path/$hdd_swtpm_uefi $image_path/$uefi_image");
        assert_script_run("wget --quiet " . data_url($sample_file) . " -P $image_path");
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
