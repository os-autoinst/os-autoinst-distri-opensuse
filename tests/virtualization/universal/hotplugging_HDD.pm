# XEN regression tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: bridge-utils libvirt-client openssh qemu-tools util-linux
# Summary: Virtual network and virtual block device hotplugging
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use Mojo::Base 'virt_feature_test_base';
use virt_autotest::common;
use virt_autotest::utils;
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
    # Set disk size=9.5G to make it to be found more easily within the guest
    assert_script_run "qemu-img create -f $disk_format $disk_image 9.5G";
    my $domblk_target = is_xen_host ? 'xvdz' : 'vdz';
    # Drop a disk left over by a previous run, but only if the guest really has it.
    # Detaching a target the domain does not have makes libvirt fail and has been seen to crash it.
    script_run("virsh domblklist $guest | grep -w ${domblk_target} && virsh detach-disk $guest ${domblk_target}", 240);
    if (try_attach("virsh attach-disk --domain $guest --source $disk_image --target ${domblk_target}")) {
        assert_script_run "virsh domblklist $guest | grep ${domblk_target}";
        assert_script_run("ssh root\@$guest lsblk");
        # Attach disk check
        script_retry("ssh root\@$guest lsblk | grep -iE '[x]?vd[a-z] +.*9.5G'", delay => 5, retry => 12, fail_message => "Failed to attach disk for guest $guest");
        assert_script_run("virsh detach-disk $guest ${domblk_target}", 240);
        # Detach disk check, the unplug is asynchronous so the guest needs time to process it
        script_retry("! ssh root\@$guest lsblk | grep -iE '[x]?vd[b-z]'", delay => 5, retry => 12, fail_message => "Failed to detach disk for guest $guest");
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
