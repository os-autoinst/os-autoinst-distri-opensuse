# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package ipmi_backend_utils;
# Summary: This file provides fundamental utilities related with the ipmi backend from test view,
#          like switching consoles between ssh and ipmi supported
# Maintainer: alice <xlai@suse.com>

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use version_utils qw/is_storage_ng/;
use utils;

our @EXPORT = qw(use_ssh_serial_console set_serial_console_on_xen switch_from_ssh_to_sol_console);

#With the new ipmi backend, we only use the root-ssh console when the SUT boot up,
#and no longer setup the real serial console for either kvm or xen.
#When needs reboot, we will switch back to sut console which relies on ipmi.
#We will mostly rely on ikvm to continue the test flow.
#TODO: we need the serial output to debug issues in reboot, coolo will help add it.

#use it after SUT boot finish, as it requires ssh connection to SUT to interact with SUT, including window and serial console
sub use_ssh_serial_console {
    console('sol')->disable;
    select_console('root-ssh');
    $serialdev = 'sshserial';
    set_var('SERIALDEV', 'sshserial');
    bmwqemu::save_vars();
}

sub switch_from_ssh_to_sol_console {
    my (%opts) = @_;

    #close root-ssh console
    prepare_system_shutdown;
    #switch to sol console
    set_var('SERIALDEV', '');
    $serialdev = 'ttyS1';
    bmwqemu::save_vars();
    console('sol')->disable;
    if ($opts{'reset_console_flag'} eq "on") {
        reset_consoles;
    }
    select_console 'sol', await_console => 0;
    save_screenshot;
}

my $grub_ver;

sub get_dom0_serialdev {
    my $root_dir = shift;
    $root_dir //= '/';

    my $dom0_serialdev;

    script_run("clear");
    script_run("cat ${root_dir}/etc/SuSE-release || cat ${root_dir}/etc/os-release");
    save_screenshot;
    assert_screen([qw(on_host_sles_12_sp2_or_above on_host_lower_than_sles_12_sp2)]);

    if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
        if (match_has_tag("on_host_sles_12_sp2_or_above")) {
            $dom0_serialdev = "hvc0";
        }
        elsif (match_has_tag("on_host_lower_than_sles_12_sp2")) {
            $dom0_serialdev = "xvc0";
        }
    }
    else {
        $dom0_serialdev = 'ttyS1';
    }

    if (match_has_tag("grub1")) {
        $grub_ver = "grub1";
    }
    else {
        $grub_ver = "grub2";
    }

    type_string("echo \"Debug info: hypervisor serial dev should be $dom0_serialdev. Grub version is $grub_ver.\"\n");

    return $dom0_serialdev;
}

sub setup_console_in_grub {
    my ($ipmi_console, $root_dir) = @_;
    $ipmi_console //= $serialdev;
    $root_dir //= '/';

    #set grub config file
    my $grub_cfg_file;
    if ($grub_ver eq "grub2") {
        $grub_cfg_file = "${root_dir}/boot/grub2/grub.cfg";
    }
    elsif ($grub_ver eq "grub1") {
        $grub_cfg_file = "${root_dir}/boot/grub/menu.lst";
    }
    else {
        die "The grub version is not supported!";
    }

    #setup serial console for xen
    my $cmd;
    if ($grub_ver eq "grub2") {
        #grub2
        $cmd
          = "cp $grub_cfg_file ${grub_cfg_file}.org "
          . "\&\& sed -ri '/(multiboot|module\\s*.*vmlinuz)/ "
          . "{s/(console|loglevel|log_lvl|guest_loglvl)=[^ ]*//g; "
          . "/multiboot/ s/\$/ console=com2,115200 log_lvl=all guest_loglvl=all sync_console/; "
          . "/module\\s*.*vmlinuz/ s/\$/ console=$ipmi_console,115200 console=tty loglevel=5/;}; "
          . "s/timeout=[0-9]*/timeout=30/g;"
          . "' $grub_cfg_file";
        assert_script_run("$cmd");
        save_screenshot;
        $cmd = "sed -rn '/(multiboot|module\\s*.*vmlinuz|timeout=)/p' $grub_cfg_file";
        assert_script_run("$cmd");
    }
    elsif ($grub_ver eq "grub1") {
        $cmd
          = "cp $grub_cfg_file ${grub_cfg_file}.org \&\&  sed -i 's/timeout [0-9]*/timeout 30/; /module \\\/boot\\\/vmlinuz/{s/console=.*,115200/console=$ipmi_console,115200/g;}' $grub_cfg_file";
        assert_script_run("$cmd");
        save_screenshot;
        $cmd = "sed -rn '/module \\\/boot\\\/vmlinuz/p' $grub_cfg_file";
        assert_script_run("$cmd");
    }
    else {
        die "Not supported grub version!";
    }
    save_screenshot;
    upload_logs("$grub_cfg_file");
}

sub mount_installation_disk {
    my ($installation_disk, $mount_point) = @_;

    #default from yast installation
    $installation_disk //= "/dev/sda2";
    $mount_point       //= "/mnt";

    #mount
    assert_script_run("mkdir -p $mount_point");
    assert_script_run("mount $installation_disk $mount_point");
    assert_script_run("ls ${mount_point}/boot");
}

sub umount_installation_disk {
    my $mount_point = shift;

    #default from yast installation
    $mount_point //= "/mnt";

    #umount
    assert_script_run("umount -l $mount_point");
    assert_script_run("ls $mount_point");
}

#Get the partition where the new installed system is installed to
sub get_installation_partition {
    my $partition = '';

    #Do not use script_output because when the command fail, script_output dies
    type_string(qq{fdisk -l | grep "^/dev/sda.*\\*" | cut -d ' ' -f 1 | tee /dev/$serialdev\n});
    $partition = wait_serial;
    $partition =~ s/^\s+|\s+$//g;
    save_screenshot;
    if (is_storage_ng && ($partition eq '')) {
        record_soft_failure "bsc#1080729 - Partitioner does not mark boot flag";
        my $y2log_file                = '/var/log/YaST2/y2log';
        my $root_partition_commit_msg = script_output(qq{grep 'Commit Action "Adding mount point / of .* to /etc/fstab' $y2log_file});
        $root_partition_commit_msg =~ m{Commit Action "Adding mount point / of ([\S]*) to /etc/fstab}m;
        $partition = $1;
    }

    die "Error: can not get installation partition!" unless ($partition);

    type_string "echo Debug info: The partition with the installed system is $partition .\n";
    save_screenshot;

    return $partition;
}

#Usage:
#For post installation, use set_serial_console_on_xen directly
#For during installation, use set_serial_console_on_xen("/mnt")
#For custom usage, use set_serial_console_on_xen($mount_point, $installation_disk)
sub set_serial_console_on_xen {
    my ($mount_point, $installation_disk) = @_;

    #prepare accessible grub
    my $root_dir;
    if ($mount_point ne "") {
        #when mount point is not empty, needs to mount installation disk
        if ($installation_disk eq "") {
            #search for the real installation partition on the first disk, which is selected by yast in ipmi installation
            $installation_disk = &get_installation_partition;
        }
        #mount partition
        assert_script_run("cd /");
        &mount_installation_disk("$installation_disk", "$mount_point");
        $root_dir = $mount_point;
    }
    else {
        $root_dir = "/";
    }

    #set up xen serial console
    my $ipmi_console = &get_dom0_serialdev("$root_dir");
    &setup_console_in_grub($ipmi_console, $root_dir);

    #cleanup mount
    if ($mount_point ne "") {
        assert_script_run("cd /");
        &umount_installation_disk("$mount_point");
    }
}


1;
