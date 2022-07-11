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

# Add a virtual CPU to the given guest
sub test_add_vcpu {
    my $guest = shift;
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    if (get_var('VIRT_AUTOTEST') && is_kvm_host && ($sles_running_version eq '11' && $sles_running_sp eq '4')) {
        record_info 'Skip vCPU hotplugging', 'bsc#1169065 vCPU hotplugging does no work on SLE 11-SP4 KVM host';
        return;
    }
    return if (is_xen_host && $guest =~ m/hvm/i);    # not supported on HVM guest

    # Ensure guest CPU count is 2
    die "Setting vcpus failed" unless (set_vcpus($guest, 2));
    assert_script_run("ssh root\@$guest nproc | grep 2", 60);
    # Add 1 CPU
    if ($sles_running_version eq '15' && $sles_running_sp eq '3' && is_xen_host && is_fv_guest($guest)) {
        record_soft_failure('bsc#1180350 Failed to set live vcpu count on fv guest on 15-SP3 Xen host');
    }
    else {
        die "Increasing vcpus failed" unless (set_vcpus($guest, 3));
        if (get_var('VIRT_AUTOTEST') && is_kvm_host && ($sles_running_version eq '15' && $sles_running_sp eq '2')) {
            record_soft_failure 'bsc#1170026 vCPU hotplugging damages ' . $guest if (script_retry("ssh root\@$guest nproc", delay => 60, retry => 3, timeout => 60, die => 0) != 0);
            #$self->{test_results}->{$guest}->{"bsc#1170026 vCPU hotplugging damages this guest $guest"}->{status} = 'SOFTFAILED' if ($vcpu_nproc != 0);
        } else {
            # bsc#1191737 Get the wrong vcpu number for 15-SP4 guest via nproc tool
            my $nproc = (is_kvm_host && $guest =~ m/sles-15-sp4-64/i) ? 'nproc --all' : 'nproc';
            script_retry("ssh root\@$guest $nproc | grep 3", delay => 60, retry => 10, timeout => 60);
        }
        # Reset CPU count to two
        die "Resetting vcpus failed" unless (set_vcpus($guest, 2));

        ## Check for bsc#1187341. This whole section can be removed once bsc#1187341 is fixed
        if ($guest eq 'sles12sp3PV') {
            sleep(60);    # Bug needs some time to actually be triggered
            if (script_run("virsh list --all | grep $guest | grep running") != 0) {
                record_soft_failure("bsc#1187341 - $guest changing number of vspus crashes $guest");
                script_run("xl dump-core > xl_coredump_$guest.log");
                upload_logs("xl_coredump_$guest.log");
                script_run("virsh start $guest");
                ensure_online("$guest");
            }
        }
    }
}

sub run_test {
    my ($self) = @_;

    record_info "SSH", "Check if guests are online with SSH";
    wait_guest_online($_) foreach (keys %virt_autotest::common::guests);

    # Hotplugging of vCPUs
    record_info("CPU", "Changing the number of CPUs available");

    foreach my $guest (keys %virt_autotest::common::guests) {
        if (virt_autotest::utils::is_sev_es_guest($guest) ne 'notsev') {
            record_info "Skip hotplugging vCPU on $guest", "SEV/SEV-ES guest $guest does not support hotplugging vCPU";
            next;
        }
        if ($guest eq "sles12sp3PV") {
            record_soft_failure("Skipping vcpu hotplugging on $guest due to bsc#1187341");
        } else {
            test_add_vcpu($guest);
        }
    }
}

sub post_fail_hook {
    my ($self) = @_;

    # Call parent post_fail_hook to collect logs on failure
    $self->SUPER::post_fail_hook;
    # Ensure guests remain in a consistent state also on failure
    reset_guest($_, $MAC_PREFIX) foreach (keys %virt_autotest::common::guests);
}

1;
