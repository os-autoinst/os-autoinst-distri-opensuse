# XEN regression tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: bridge-utils libvirt-client openssh qemu-tools util-linux
# Summary: Virtual network and virtual block device hotplugging
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>, Jan Baier <jbaier@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use virt_utils;
use version_utils;
use hotplugging_utils;

# Magic MAC prefix for temporary devices. Must be of the format 'XX:XX:XX:XX'
my $MAC_PREFIX = '00:16:3f:32';

# Add a virtual disk to the given guest
sub test_add_virtual_disk {
    my $guest = shift;
    my $disk_format = get_var("QEMU_DISK_FORMAT") // "raw";
    my $disk_image = get_disk_image_name($guest, $disk_format);

    assert_script_run("rm -f $disk_image");
    assert_script_run "qemu-img create -f $disk_format $disk_image 10G";
    my $domblk_target = 'vdz';
    $domblk_target = 'xvdz' if (is_xen_host);
    script_run("virsh detach-disk $guest ${domblk_target}", 240);
    if (try_attach("virsh attach-disk --domain $_ --source $disk_image --target ${domblk_target}")) {
        assert_script_run "virsh domblklist $guest | grep ${domblk_target}";
        # Skip lsblk check for VIRT_AUTOTEST KVM test suites after attaching raw disk due to uncertainty
        if (!get_var('VIRT_AUTOTEST')) {
            if (is_kvm_host) {
                my $lsblk = script_run("ssh root\@$guest lsblk | grep 'vd[b-z]'", 60);
                record_info("lsblk failed - please check the output manually", result => 'softfail') if $lsblk != 0;
            } elsif (is_xen_host) {
                my $lsblk = script_run("ssh root\@$guest lsblk | grep 'xvd[b-z]'", 60);
                record_info("lsblk failed - please check the output manually", result => 'softfail') if $lsblk != 0;
            } else {
                my $msg = "Unknown virtualization hosts";
                record_info($msg, result => 'softfail');
            }
        }
        assert_script_run("ssh root\@$guest lsblk");
        assert_script_run("virsh detach-disk $guest ${domblk_target}", 240);
    }
    assert_script_run("rm -f $disk_image");
}

sub run_test {
    my ($self) = @_;
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    record_info "SSH", "Check guests are online with SSH";
    wait_guest_online($_) foreach (keys %virt_autotest::common::guests);

    # Hotplug HDD
    my $lsblk = 0;
    my $disk_format = get_var("QEMU_DISK_FORMAT") // "raw";
    record_info "Disk", "Adding another raw disk";
    assert_script_run "mkdir -p /var/lib/libvirt/images/add/";
    test_add_virtual_disk($_) foreach (keys %virt_autotest::common::guests);
}

sub post_fail_hook {
    my ($self) = @_;

    # Call parent post_fail_hook to collect logs on failure
    $self->SUPER::post_fail_hook;
    # Ensure guests remain in a consistent state also on failure
    reset_guest($_, $MAC_PREFIX) foreach (keys %virt_autotest::common::guests);
}

1;
