# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: prepare USB for baremetal installation via ISO.
# On a minimum system that is launched by ipxe and stops
# at sshd-server-started, dd installation iso to one usb,
# write ignition and combustion config to the other usb,
# and launch the installation with the iso usb.
# Maintainer: Xiaoli Ai(Alice) <xlai@suse.com>, qe-virt@suse.de

package usb_install;
use base 'y2_installbase';
use strict;
use warnings;

use utils;
use testapi;
use bmwqemu;
use ipmi_backend_utils;
use Utils::Architectures;
use LWP::Simple 'head';
use Utils::Backends 'use_ssh_serial_console';

sub run {
    assert_screen('sshd-server-started', 5);
    use_ssh_serial_console;
    assert_script_run("set -o pipefail");

    # Specify the two usb drives to use
    my @usb = split('\n', script_output("ls /dev/disk/by-id/ -l | grep -i usb | grep -i -v -E \"generic|part\" | sed 's#^.*\\\/##'"));
    record_info("Disk info on the machine:", script_output("ls /dev/disk/by-id/ -l; fdisk -l"));
    die "No proper usb devices!" unless (scalar(@usb) == 2);
    my $medium_usb = "/dev/$usb[0]";
    my $provision_usb = "/dev/$usb[1]";
    record_info("Pick usb drive $medium_usb to store ISO and $provision_usb to store ignition and combustion config.");

    # Write ignition config to one usb
    assert_script_run("echo y | mkfs.ext4 $provision_usb", 60);
    assert_script_run("e2label $provision_usb ignition");
    assert_script_run("mkdir  -p /mnt");
    assert_script_run("mount $provision_usb /mnt");
    assert_script_run("mkdir -p /mnt/ignition");
    my $cmd = "curl -L "
      . data_url("virt_autotest/host_unattended_installation_files/ignition/config.ign")
      . " -o /mnt/ignition/config.ign";
    script_retry($cmd, retry => 2, delay => 5, timeout => 60, die => 1);
    save_screenshot;
    assert_script_run("ls /mnt/ignition/config.ign");
    save_screenshot;

    # Write combustion script to the same usb with ignition
    assert_script_run("mkdir -p /mnt/combustion");
    $cmd = "curl -L "
      . data_url("virt_autotest/host_unattended_installation_files/combustion/script")
      . " -o /mnt/combustion/script";
    script_retry($cmd, retry => 2, delay => 5, timeout => 60, die => 1);
    save_screenshot;
    my $SERIALCONSOLE = get_required_var('SERIALCONSOLE');
    assert_script_run("sed -i 's/SERIALCONSOLE/$SERIALCONSOLE/g' /mnt/combustion/script");
    assert_script_run("chmod a+x /mnt/combustion/script");
    assert_script_run("ls -l /mnt/combustion/script");
    save_screenshot;
    record_info('Ignition and combustion content:', script_output('cat /mnt/ignition/config.ign /mnt/combustion/script'));

    # Flush to usb stick
    assert_script_run("sync");
    assert_script_run("umount -l /mnt");
    record_info("Ignition and combustion files are successfully downloaded and written to usb $provision_usb.");

    # Download and dd the iso to the other usb
    my $download_url = "http://" . get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME')) . "/assets/iso/" . get_required_var('ISO');
    die "ISO URL is not accessible: $download_url." unless head($download_url);
    $cmd = "curl -L $download_url | dd of=$medium_usb bs=1M";
    script_retry($cmd, retry => 2, delay => 10, timeout => 600, die => 1);
    save_screenshot;

    # Flush
    assert_script_run("sync");
    record_info("ISO is saved successfully to usb $medium_usb.");

    # Set next boot to usb
    if (is_uefi_boot) {
        # Some machines do not support setting floppy boot via ipmitool in uefi boot mode,
        # so we use efibootmgr instead
        record_info('efibootmgr output after dd iso to usb:', script_output('efibootmgr -v'));
        save_screenshot;
        my $UEFI_USB_BOOT_LABEL = "OpenQA-added-UEFI-USB-BOOT";

        # Delete the sle micro usb boot entry if it exists already
        # (old boot entry survives new installation)
        my $output = '';
        my $usb_boot_num = '';
        my $cmd = "efibootmgr | grep $UEFI_USB_BOOT_LABEL";
        if (script_run("$cmd") == 0) {
            $output = script_output("$cmd");
            save_screenshot;
            $output =~ /Boot([0-9A-F]+)\*/m;
            $usb_boot_num = $1;
            assert_script_run("efibootmgr -B -b $usb_boot_num");
            record_info("Existing UEFI boot for $UEFI_USB_BOOT_LABEL is deleted.", script_output('efibootmgr -v'));
        }

        # Add new sle micro usb boot entry
        $cmd = "efibootmgr -c -d $medium_usb -p 2 -L $UEFI_USB_BOOT_LABEL -l /EFI/BOOT/grub.efi";
        assert_script_run("$cmd");
        save_screenshot;
        $cmd = "efibootmgr | grep $UEFI_USB_BOOT_LABEL";
        $output = script_output("$cmd");
        $output =~ /Boot([0-9A-F]+)\*/m;
        $usb_boot_num = $1;
        assert_script_run("efibootmgr -n $usb_boot_num");
        save_screenshot;
        record_info("UEFI boot for $UEFI_USB_BOOT_LABEL is added", script_output('efibootmgr -v'));
    } else {
        set_floppy_boot;
    }

    # Power reset
    ipmitool("chassis power reset");
    reset_consoles;
    select_console 'sol', await_console => 0;
}

1;
