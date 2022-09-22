# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use File::Basename;
use testapi;
use virt_utils 'clean_up_red_disks';
use base 'reboot_and_wait_up';
use virt_autotest::utils;
use opensusebasetest;

#Explanation for parameters introduced to facilitate offline host upgrade:
#OFFLINE_UPGRADE indicates whether host upgrade is offline which needs reboot
#the host and upgrade from installation media. Please refer to this document:
#https://susedoc.github.io/doc-sle/main/single-html/SLES-upgrade/#cha-upgrade-offline
#UPGRADE_AFTER_REBOOT is used to control whether reboot is followed by host
#offline upgrade procedure which needs to be treated differently compared with
#usual reboot and then login.
sub run {
    my $self = shift;

    #initialized to be offline upgrade
    my $timeout = 180;
    set_var('UPGRADE_AFTER_REBOOT', '1');
    set_var('OFFLINE_UPGRADE', '1');

    #get the version that the host is installed to
    my $host_installed_version = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));    #format 15 or 15-SP1
    ($host_installed_version) = $host_installed_version =~ /^(\d+)/;
    #get the version that the host should upgrade to
    my $host_upgrade_version = get_required_var('UPGRADE_PRODUCT');    #format sles-15-sp0
    ($host_upgrade_version) = $host_upgrade_version =~ /sles-(\d+)-sp/i;
    diag("Debug info for reboot_and_wait_up_upgrade: host_installed_version is $host_installed_version, host_upgrade_version is $host_upgrade_version");
    #online upgrade actually
    if ("$host_installed_version" eq "$host_upgrade_version") {
        set_var('OFFLINE_UPGRADE', '');
        $timeout = 120;
        diag("Debug info for reboot_and_wait_up_upgrade: this is online upgrade");
    }
    else {
        #OpenQA needs ssh way to trigger offline upgrade
        script_run("sed -i s/sshd=1/ssh=1/g /boot/grub2/grub.cfg /boot/grub/menu.lst");
        diag("Debug info for reboot_and_wait_up_upgrade: this is offline upgrade. Need to clean up redundant disks using clean_up_red_disks.");
        clean_up_red_disks unless check_var('VIRT_PRJ2_HOST_UPGRADE', '');
    }

    $self->reboot_and_wait_up($timeout);
}

sub post_fail_hook {
    my ($self) = shift;
    reset_consoles;
    select_console('root-ssh');
    if (get_var('VIRT_PRJ2_HOST_UPGRADE')) {
        if (get_var('OFFLINE_UPGRADE')) {
            #host offline upgrade
            $self->upload_y2logs;
            upload_logs("/mnt/root/autoupg.xml", failok => 1);
        }
        else {
            #host online upgrade
            $self->upload_coredumps;
            save_screenshot;

            virt_utils::collect_host_and_guest_logs;
        }
    }
    $self->SUPER::post_fail_hook;
}

1;
