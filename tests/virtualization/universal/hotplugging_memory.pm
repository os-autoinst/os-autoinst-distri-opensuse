# XEN regression tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: bridge-utils libvirt-client openssh qemu-tools util-linux
# Summary: Virtual network and virtual block device hotplugging
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>, Jan Baier <jbaier@suse.cz>

use base "virt_feature_test_base";
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

sub test_vmem_change {
    my $guest = shift;
    if (is_sle) {
        my ($sles_running_version, $sles_running_sp) = get_os_release;
        if (get_var('VIRT_AUTOTEST') && ($sles_running_version lt '12' or ($sles_running_version eq '12' and $sles_running_sp lt '3'))) {
            record_info('Skip memory hotplugging on outdated before-12-SP3 SLES product because immature memory handling situations');
            return;
        }
    }
    return if (is_xen_host && $guest =~ m/hvm/i);    # memory change not supported on HVM guest
    set_guest_memory($guest, 2048, 1500, 2252);    # Lower memory limit is set to 80%, which is enough to distinguish between 2G and 3G
    set_guest_memory($guest, 3072, 2457, 3379);
    set_guest_memory($guest, 2048, 1500, 2252);
}

sub run_test {
    my ($self) = @_;
    my @guests = @{get_var_array("TEST_GUESTS")};
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    record_info "SSH", "Check if guests are online with SSH";
    wait_guest_online($_, 300, 1) foreach (@guests);

    # Live memory change of guests
    record_info "Memory", "Changing the amount of memory available";
    test_vmem_change($_) foreach (@guests);

    # Workaround to drop all live provisions of all vm guests
    if (get_var('VIRT_AUTOTEST') && is_kvm_host && (($sles_running_version eq '12' and $sles_running_sp eq '5') || ($sles_running_version eq '15' and $sles_running_sp eq '1'))) {
        record_info "Reboot All Guests", "Mis-handling of live and config provisions by other test modules may have negative impact on 12-SP5 and 15-SP1 KVM scenarios due to bsc#1171946. So here is the workaround to drop all live provisions by rebooting all vm guests.";
        perform_guest_restart;
    }
}

sub post_fail_hook {
    my ($self) = @_;
    my @guests = @{get_var_array("TEST_GUESTS")};

    # Call parent post_fail_hook to collect logs on failure
    $self->SUPER::post_fail_hook;
    # Ensure guests remain in a consistent state also on failure
    reset_guest($_, $MAC_PREFIX) foreach (@guests);
}

1;
