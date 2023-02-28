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

# Add a virtual network interface for the given guest and return the determined MAC address
sub add_virtual_network_interface {
    my $self = shift;
    my $guest = shift;
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    my $mac = "$MAC_PREFIX:" . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
    unless ($guest =~ m/hvm/i && is_sle('<=12-SP2') && is_xen_host) {
        my $persistent_config_option = '';
        my $interface_model_option = '';
        if (get_var('VIRT_AUTOTEST') && is_xen_host) {
            record_soft_failure 'bsc#1168124 Bridge network interface hotplugging has to be performed at the beginning.';
            $self->{test_results}->{$guest}->{"bsc#1168124 Bridge network interface hotplugging has to be performed at the beginning"}->{status} = 'SOFTFAILED';
        }
        if (get_var('VIRT_AUTOTEST') && is_kvm_host) {
            $interface_model_option = '--model virtio';
        }
        script_retry("ssh root\@$guest ip l | grep " . $virt_autotest::common::guests{$guest}->{macaddress}, delay => 60, retry => 10, timeout => 60);
        assert_script_run("virsh domiflist $guest", 90);
        if (try_attach("virsh attach-interface --domain $guest --type bridge ${interface_model_option} --source br0 --mac " . $mac . " --live " . ${persistent_config_option})) {
            assert_script_run("virsh domiflist $guest | grep br0");
            assert_script_run("ssh root\@$guest cat /proc/uptime | cut -d. -f1", 60);
            script_retry("ssh root\@$guest ip l | grep " . $mac, delay => 60, retry => 3, timeout => 60);
            assert_script_run("virsh detach-interface $guest bridge --mac " . $mac);
            die "Failed to detach bridge interface for guest $guest." if (script_run("ssh root\@$guest ip l | grep " . $mac, 60) eq 0);
        }
    } else {
        record_soft_failure 'bsc#959325 - Live NIC attachment on <=12-SP2 Xen hypervisor with HVM guests does not work correctly.';
    }
    return $mac;
}

sub run_test {
    my ($self) = @_;
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    record_info "SSH", "Check if guests are online with SSH";
    wait_guest_online($_) foreach (keys %virt_autotest::common::guests);

    # Add network interfaces
    my %mac = ();
    record_info "Virtual network", "Adding virtual network interface";
    $mac{$_} = add_virtual_network_interface($self, $_) foreach (keys %virt_autotest::common::guests);
}

sub post_fail_hook {
    my ($self) = @_;

    # Call parent post_fail_hook to collect logs on failure
    $self->SUPER::post_fail_hook;
    # Ensure guests remain in a consistent state also on failure
    reset_guest($_, $MAC_PREFIX) foreach (keys %virt_autotest::common::guests);
}

1;
