# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package reset_partition;
# Summary: reset_partition: Ensure and reset hard disk partition for virt_autotest.
# Maintainer: Leon Guo <xguo@suse.com>

use base "virt_feature_test_base";
use strict;
use warnings;
use testapi;
use virt_utils;
use ipmi_backend_utils;
use Utils::Architectures;
use utils qw(zypper_call);
use version_utils 'is_sle';
use virt_autotest::utils qw(is_xen_host);

sub reset_partition {
    my ($libvirt_disk) = @_;
    my $new_disk       = "";
    my $virt_point     = "/var/lib/libvirt/";

    # Install requested pkgs
    my @pkgs = qw/xfsprogs coreutils util-linux/;
    zypper_call "in @pkgs";

    # Get some debug info about hard disk topology
    record_info("Report file system disk space", script_output("df"));
    record_info("Find mounted filesystem",       script_output("findmnt"));

    # Check with all existed Hard disks
    my @disks = split(/\n/, script_output("lsblk -n -l -o NAME -d -e 7,11"));
    my $dev   = "/dev/";
    foreach my $disk (@disks) {
        assert_script_run('file ' . $dev . $disk);
    }

    # Use the first disk or the second(if libvirt image takes the first disk already) as the new disk
    if ($libvirt_disk eq $disks[0]) {
        $new_disk = $dev . $disks[1];
    } else {
        $new_disk = $dev . $disks[0];
    }
    record_info('Assign a New Disk:', $new_disk);

    # Wipe Hard Disk Clean via dd for assigned a new full disk
    assert_script_run("dd if=/dev/zero of=$new_disk count=1M", timeout => 1500, fail_message => "Failed to wipe hard disk clean on $new_disk");

    # Create New Disk Partition
    assert_script_run 'echo -e "g\nn\n\n\n\nt\n8e\np\nw" | fdisk ' . $new_disk;

    # Ensure the original filesystem type
    my $original_fs_type = script_output("lsblk -f | grep libvirt | awk '{print \$2}'");

    # Format New Disk Partition
    $new_disk .= 1;
    assert_script_run "mkfs.$original_fs_type -f $new_disk";

    # Umount existed /var/lib/libvirt mounted point
    assert_script_run "umount -f -l $virt_point";

    # Wipe existed /var/lib/libvirt mounted point from /etc/fstab
    script_run "sed -i '/\\/var\\/lib\\/libvirt/d' /etc/fstab";

    # Add a new /var/lib/libvirt mounted point to /etc/fstab
    assert_script_run "echo '$new_disk $virt_point xfs defaults 0 0' >> /etc/fstab";

    # Mount the new /var/lib/libvirt mounted point
    assert_script_run "mount -a";

    my @dirs = qw/boot dnsmasq filesystems images network qemu swtpm/;
    push @dirs, qw(libxl lxc) if (is_xen_host);
    foreach my $dir (@dirs) {
        assert_script_run('mkdir -p ' . $virt_point . $dir);
    }

    # Check with new /var/lib/libvirt mounted point
    record_info("System MOUNT Info",       script_output("mount"));
    record_info("List Block Devices",      script_output("lsblk"));
    record_info("Ensure /var/lib/libvirt", script_output("ls -al /var/lib/libvirt"));

}

sub run {
    my $self = shift;

    # Refer ticket https://progress.opensuse.org/issues/78986
    # Currently just only s15sp3 had hit this problem without s12+, so just enable this test module for s15+(x86_64) now
    # If once the same problem reproduce on s12+, will support s12+
    return if (is_sle("<15") or !is_x86_64);
    my ($VIRT_DISK_NAME, $VIRT_AVAILABLE_SIZE) = $self->get_virt_disk_and_available_space();
    # Disk which /var/lib/libvirt resides on:
    record_info('Detect DISK NAME:', $VIRT_DISK_NAME);
    # Ensure available disk space
    record_info('Detect Available DISK SIZE:', $VIRT_AVAILABLE_SIZE . 'GiB');
    # Define the expected disk space to store guest images both on KVM or XEN
    my $expected_libvirt_size = (is_xen_host) ? '60' : '40';

    reset_partition($VIRT_DISK_NAME) if ($expected_libvirt_size > $VIRT_AVAILABLE_SIZE);

}

sub test_flags {
    return {fatal => 1};
}

1;
