# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use File::Basename;
use testapi;
use virt_utils 'clean_up_red_disks';
use base 'reboot_and_wait_up';

sub run {
    my $self = shift;

    #initialized to be offline upgrade
    my $timeout = 180;
    set_var("reboot_for_upgrade_step", "yes");
    set_var("offline_upgrade",         "yes");

    #get the version that the host is installed to
    my $host_installed_version = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));    #format 15 or 15-SP1
    ($host_installed_version) = $host_installed_version =~ /^(\d+)/;
    #get the version that the host should upgrade to
    my $host_upgrade_version = get_required_var('UPGRADE_PRODUCT');                        #format sles-15-sp0
    ($host_upgrade_version) = $host_upgrade_version =~ /sles-(\d+)-sp/i;
    diag("Debug info for reboot_and_wait_up_upgrade: host_installed_version is $host_installed_version, host_upgrade_version is $host_upgrade_version");
    #online upgrade actually
    if ("$host_installed_version" eq "$host_upgrade_version") {
        set_var("offline_upgrade", "no");
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

1;
