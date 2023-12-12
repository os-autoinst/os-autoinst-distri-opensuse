# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: 
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
#use version_utils qw(is_upgrade is_tumbleweed is_sle is_leap);
use Utils::Architectures;
use LWP::Simple 'head';
#use Time::HiRes 'sleep';

sub run {
    assert_screen('sshd-server-started', 5);
    select_console('root-ssh');
    assert_script_run("set -o pipefail");

    # specify the two usb drives to use 
    my @usb = split('\n', script_output("ls /dev/disk/by-id/ -l | grep -i usb | grep -i -v -E \"generic|part\" | sed 's#^.*\\\/##'"));
    record_info("Disk info on the machine:", script_output("ls /dev/disk/by-id/ -l; fdisk -l"));
    die "No proper usb devices!" unless (@usb && scalar(@usb) == 2);
    my $iso_usb = "/dev/$usb[0]";
    my $ignition_usb = "/dev/$usb[1]";
    record_info("Pick usb drive $iso_usb to store ISO and $ignition_usb to store ignition config.");

    # write ignition config to one usb
    assert_script_run("echo y | mkfs.ext4 $ignition_usb", 60);
    assert_script_run("e2label $ignition_usb ignition");
    assert_script_run("mkdir  -p /mnt");
    assert_script_run("mount $ignition_usb /mnt");
    assert_script_run("mkdir -p /mnt/ignition");
    my $cmd = "curl -L "
      . data_url("virt_autotest/host_unattended_installation_files/ignition/config.ign")
      . " -o /mnt/ignition/config.ign";
    script_retry($cmd, retry => 2, delay => 5, timeout => 60, die => 1);
    save_screenshot;
    assert_script_run("cat /mnt/ignition/config.ign");
    save_screenshot;

    # write combustion script to the same usb with ignition
    assert_script_run("mkdir -p /mnt/combustion");
    $cmd = "curl -L "
      . data_url("virt_autotest/host_unattended_installation_files/combustion/script")
      . " -o /mnt/combustion/script";
    script_retry($cmd, retry => 2, delay => 5, timeout => 60, die => 1);
    save_screenshot;
    assert_script_run("chmod a+x /mnt/combustion/script");
    assert_script_run("ls -l /mnt/combustion/script && cat /mnt/combustion/script");
    save_screenshot;

    # flush to usb stick
    assert_script_run("sync");
    assert_script_run("umount -l /mnt");
    record_info("Ignition and combustion files are successfully downloaded and written to usb $ignition_usb.");

    # download and dd the iso to the other usb
    my $download_url = "http://" . get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME')) . "/assets/iso/" . get_required_var('ISO');
    die "ISO URL is not accessible: $download_url." unless head($download_url);
    $cmd = "curl -L $download_url | dd of=$iso_usb bs=1M";
    script_retry($cmd, retry => 2, delay => 10, timeout => 600, die => 1);
    save_screenshot;
#    my $checksum = script_output("sha256sum $usb" . ' |cut -d\' \' -f 1', 210);
#    if ($checksum eq get_required_var('CHECKSUM_ISO')) {
#        record_info("ISO successfully dd to $usb.", "ISO source $download_url.");
#    } else {
#        die("ISO dd to $usb failed.\nISO source $download_url.\nExpected sha256sum: " . get_required_var('CHECKSUM_ISO') . ".\nReal sha256sum: $checksum.");
#    }

    # flush
    assert_script_run("sync");
    record_info("ISO is saved successfully to usb $iso_usb.");


    # set next boot to usb
    if (check_var('IPXE_UEFI', '1')) {
	# some machines do not support setting floppy boot via ipmitool in uefi boot mode, 
	# so we use efibootmgr instead
	record_info('efibootmgr output after dd iso to usb:', script_output('efibootmgr'));
	save_screenshot;
	my $usb_boot = script_output('efibootmgr | grep usb -i | grep "\*"');
	save_screenshot;
	die "Only 1 bootable USB should be here. But we find in efibootmgr output: $usb_boot." if (!$usb_boot || $usb_boot =~ /\n/);
	$usb_boot =~ /Boot([0-9A-F]+)\*/m;
	my $usb_boot_num = $1;
	assert_script_run("efibootmgr -n $usb_boot_num");
	save_screenshot;
	record_info('efibootmgr output after setting next boot to usb:', script_output('efibootmgr'));
    } else {
    	set_floppy_boot;
    }

    # power reset
    ipmitool("chassis power reset");

    select_console 'sol', await_console => 0;
    #assert_screen('press-t-for-boot-menu', 180);
    #send_key('t');
}

#sub post_fail_hook {
#    # ipmitool boot to disk
#    # super::post_fail_hook
#    my $self = shift;
#
#    # To not affect following jobs 
#    set_disk_boot;
#    #$self->SUPER::post_fail_hook;
#}

1;
