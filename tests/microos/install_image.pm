# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install SL Micro image on bare metal disk
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

use Utils::Backends;
use Utils::Architectures 'is_x86_64';
use power_action_utils 'power_action';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Use image name from HDD_1 variable
    my $image = get_required_var('HDD_1');
    # Use sda as target disk by default
    my $device = get_var("MICRO_INSTALL_IMAGE_TARGET_DEVICE", "/dev/sda");
    # Use partition prefix for nvme devices
    my $prefix = $device =~ /nvme/ ? "p" : "";
    # SL Micro x86_64 image has three partitions, aarch64 and ppc64le images have only two partitions
    my $root_partition_id = is_x86_64 ? 3 : 2;
    my $root_partition = "${device}" . $prefix . $root_partition_id;
    # New partition id for ignition will be directly after root partition
    my $ignition_partition_id = $root_partition_id + 1;
    my $ignition_partition = "${device}" . $prefix . $ignition_partition_id;
    record_info("Device information", "Device: ${device}\nRoot partition: ${root_partition}\nIgnition partition: ${ignition_partition}");

    # Mount nfs share with images
    assert_script_run("mount -o ro,noauto,nofail,nolock -t nfs openqa.suse.de:/var/lib/openqa/share /mnt");
    assert_script_run("ls -als /mnt/factory/hdd/${image}");
    # dd image to disk
    assert_script_run("xzcat /mnt/factory/hdd/${image} | dd of=${device} bs=65536 status=progress", timeout => 300);
    assert_script_run("sync");
    assert_script_run("umount /mnt");

    my $device_layout = script_output("lsblk");
    record_info("Device layout", ${device_layout});

    # Modify disk to be able to correctly boot and login
    assert_script_run("mount ${root_partition} /mnt");
    assert_script_run("btrfs property set /mnt ro false");
    # Set correct serial console to be able to see login in first boot
    assert_script_run("sed -i 's/console=ttyS0,115200/console=ttyS1,115200/g' /mnt/boot/grub2/grub.cfg") if is_x86_64;
    # Upload original grub configuration
    upload_logs("/mnt/etc/default/grub", failok => 1);
    # Set permanent grub configuration
    assert_script_run("sed -i 's/console=ttyS0,115200/console=ttyS1,115200/g' /mnt/etc/default/grub") if is_x86_64;
    # Fully disable graphical terminal on legacy systems without UEFI
    my $grub_terminal_io = is_ipmi && !get_var('IPXE_UEFI') ? 'console' : 'console gfxterm';
    assert_script_run("sed -i 's/GRUB_TERMINAL_INPUT=\".*\"/GRUB_TERMINAL_INPUT=\"${grub_terminal_io}\"/g' /mnt/etc/default/grub");
    assert_script_run("sed -i 's/GRUB_TERMINAL_OUTPUT=\".*\"/GRUB_TERMINAL_OUTPUT=\"${grub_terminal_io}\"/g' /mnt/etc/default/grub");
    # Enable root loging with password
    assert_script_run("echo 'PermitRootLogin yes' > /mnt/etc/ssh/sshd_config.d/root.conf");
    assert_script_run("btrfs property set /mnt ro true");
    assert_script_run("umount /mnt");

    # Setup ignition parition on the end of the same disk and resize root partition to use all the space
    # script_output recommended in https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/20253/files#r1776549682
    script_output("printf \"fix\n\" | parted ---pretend-input-tty ${device} print");
    assert_script_run("parted ${device} --script mkpart primary ext4 98% 100%");
    assert_script_run("parted ${device} --script print");
    assert_script_run("mkfs.ext4 -F ${ignition_partition}");
    assert_script_run("e2label ${ignition_partition} ignition");
    assert_script_run("mount ${ignition_partition} /mnt/");
    assert_script_run("mkdir /mnt/ignition");
    assert_script_run("curl -v -o /mnt/ignition/config.ign " . data_url("microos/ignition/config.ign"));
    assert_script_run('umount /mnt');

    # Resize root filesystem to maximum size to use all space up to partition with ignition
    assert_script_run("parted ${device} --script resize ${root_partition_id} 98%");
    assert_script_run("mount ${root_partition} /mnt");
    assert_script_run("btrfs filesystem resize max /mnt");
    assert_script_run("umount /mnt");
    my $final_disk_layout = script_output("parted ${device} --script print");
    record_info("INFO", "${image} was installed on ${device}. System is going to be rebooted.\n\nFinal disk layout:\n ${final_disk_layout}");

    # We have to use force option to reboot command as installer doesn't have fully running systemd environment
    power_action("reboot", textmode => 1, force => 1);

    # We can't use reconnect_mgmt_console as it expects fully configured grub, which we don't have at this stage yet
    select_console "sol", await_console => 0 if is_ipmi;
    select_console 'powerhmc-ssh', await_console => 0 if is_pvm_hmc;
    assert_screen("linux-login", 600);
}

sub test_flags {
    return {fatal => 1};
}

1;
