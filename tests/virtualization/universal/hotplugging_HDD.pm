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
    # Detach unconditionally, libvirt has to reject a detach for a device that is not there
    # gracefully (bsc#1272852). script_run reports the real exit code, 128 + signum when the
    # process is killed by a signal. script_output cannot, it runs the command under 'bash -e'.
    my $detach_cmd = "virsh detach-disk $guest ${domblk_target}";
    my $detach_rc = script_run("$detach_cmd > /tmp/detach.log 2>&1", 240);
    my $detach_output = script_output('cat /tmp/detach.log', proceed_on_failure => 1);
    my $detach_crashed = $detach_rc >= 128
      || $detach_output =~ m/End of file|Cannot recv data|failed to connect/;
    record_info("Detach ${domblk_target}", "exit code $detach_rc\n$detach_output",
        result => $detach_crashed ? 'fail' : 'ok');
    if (try_attach("virsh attach-disk --domain $guest --source $disk_image --target ${domblk_target}")) {
        assert_script_run "virsh domblklist $guest | grep ${domblk_target}";
        assert_script_run("ssh root\@$guest lsblk");
        # Attach disk check
        script_retry("ssh root\@$guest lsblk | grep -iE '[x]?vd[a-z] +.*9.5G'", delay => 5, retry => 12, fail_message => "Failed to attach disk for guest $guest");
        assert_script_run($detach_cmd, 240);
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
