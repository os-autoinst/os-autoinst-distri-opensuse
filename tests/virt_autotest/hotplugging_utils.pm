# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
# Summary: virtualization test utilities.
# Maintainer: QE-Virtualization <qe-virt@suse.de>

package hotplugging_utils;

use base Exporter;
use strict;
use warnings;
use utils;
use version_utils;
use testapi;
use File::Basename;
use Utils::Architectures;

our @EXPORT = qw(set_vcpus set_guest_memory get_guest_memory get_disk_image_name reset_guest try_attach);

# Subroutine to change number of vCPUs for guest
sub set_vcpus {
    my ($guest, $vcpus) = @_;
    assert_script_run("virsh setvcpus --domain $guest --count $vcpus --live");
    return script_run("virsh vcpucount $guest | grep current | grep live | grep $vcpus") == 0;
}

# Set memory of the given guest to the given size in MB
sub set_guest_memory {
    my $guest = shift;
    my $memory = shift;
    my $min_memory = shift // 0.9 * $memory;    # acceptance range for memory check
    my $max_memory = shift // 1.1 * $memory;    # acceptance range for memory check

    assert_script_run("virsh setmem --domain $guest --size $memory" . "M --live");
    assert_script_run("virsh dommemstat $guest");
    assert_script_run("ssh root\@$guest free", 60);
    sleep 5;    # give the VM some time to adjust
    my $guestmemory = get_guest_memory($guest);
    # Memory reposts are not precise, we allow for a +/-10% acceptance range
    my $within_tolerance = ($min_memory <= $guestmemory) && ($guestmemory <= $max_memory);
    record_info('Softfail', "Set live memory failed - expected $memory but got $guestmemory", result => 'softfail') unless ($within_tolerance);
}

# Returns guest memory in MB
sub get_guest_memory {
    my $guest = shift;
    my $kernelmemory = 200000;    # We account to kernel memory to measures which omit it by adding this amount to the measured value

    my $memory = 0;
    $memory = script_output("ssh $guest cat /proc/meminfo | grep MemTotal | awk '{print \$2}'", proceed_on_failure => 1);
    return ($memory + $kernelmemory) / 1024 if (defined($memory) && $memory > 0);

    # Fallback to use `free`
    $memory = script_output("ssh $guest free | grep Mem | awk '{print \$2}'", proceed_on_failure => 1) + $kernelmemory;
    return ($memory + $kernelmemory) / 1024 if (defined($memory) && $memory > 0);

    return 0;
}

# Get guests disk device name
sub get_disk_image_name {
    my $guest = shift;
    my $disk_format = shift // get_var("QEMU_DISK_FORMAT");
    $disk_format //= "raw";    # Fallback in case nor function argument not QEMU_DISK_FORMAT setting is set
    my $disk_image = "/var/lib/libvirt/images/add/$guest.$disk_format";
    return $disk_image;
}

# Reset guest preferences and cleanup changes done by adding NIC devices, additional HDDs, vCPUs and memory device tests.
sub reset_guest {
    my $guest = shift;
    return if $guest == "";
    my $guest_instance = $virt_autotest::common::guests{$guest};
    my $MAC_PREFIX = $_[1];

    ## Network
    # Remove temporary NIC devices, those are identified by a MAC starting with "$MAC_PREFIX"
    remove_additional_nic($guest, $MAC_PREFIX);
    ## Disk cleanup
    my $disk_image = get_disk_image_name($guest);
    remove_additional_disks($guest);
    script_run("rm -f $disk_image");
    ## CPU and memory
    set_vcpus($guest, 2);
    my $memory = $guest_instance->{memory} // "2048";
    set_guest_memory($guest, $memory);
    # max memory
    my $maxmemory = $guest_instance->{maxmemory} // "4096";
    script_run("virsh setmaxmem $_ $maxmemory" . "M --config") foreach (keys %virt_autotest::common::guests);
}

# Try to attach a NIC or disk device and check for bsc1175218
sub try_attach {
    my $cmd = shift;
    if (script_run($cmd) != 0) {
        # Check for https://bugzilla.suse.com/show_bug.cgi?id=1175218
        if (script_run($cmd . " 2>&1 | grep 'No more available PCI slots'") == 0) {
            record_soft_failure("bsc#1175218 No more available PCI slots when attaching network interface");
            return 0;
        } else {
            die "virsh attach failed";
        }
    }
    return 1;
}

1;
