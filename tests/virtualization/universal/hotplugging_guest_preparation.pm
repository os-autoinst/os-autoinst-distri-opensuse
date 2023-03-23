# XEN regression tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: bridge-utils libvirt-client openssh qemu-tools util-linux
# Summary: Virtual network and virtual block device hotplugging
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "virt_feature_test_base";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use virt_utils;
use version_utils qw(is_alp get_os_release);
use hotplugging_utils;
use virt_autotest::virtual_network_utils qw(update_simple_dns_for_all_vm);

# Magic MAC prefix for temporary devices. Must be of the format 'XX:XX:XX:XX'
my $MAC_PREFIX = '00:16:3f:32';

sub run_test {
    my ($self) = @_;
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    # Update dns records if needed
    if ($sles_running_version eq '15' && get_var("VIRT_AUTOTEST") && !get_var("VIRT_UNIFIED_GUEST_INSTALL")) {
        record_info("DNS Setup", "SLE 15+ host may have more strict rules on dhcp assigned ip conflict prevention, so guest ip may change");
        my $dns_bash_script_url = data_url("virt_autotest/setup_dns_service.sh");
        script_output("curl -s -o ~/setup_dns_service.sh $dns_bash_script_url", 180, type_command => 0, proceed_on_failure => 0);
        script_output("chmod +x ~/setup_dns_service.sh && ~/setup_dns_service.sh -f testvirt.net -r 123.168.192 -s 192.168.123.1", 180, type_command => 0, proceed_on_failure => 0);
        upload_logs("/var/log/virt_dns_setup.log");
        save_screenshot;
    } elsif (is_alp) {
        update_simple_dns_for_all_vm('test-virt-net');
    }

    # Guest preparation
    shutdown_guests();
    reset_guest($_, $MAC_PREFIX) foreach (keys %virt_autotest::common::guests);
    start_guests();
}

sub post_fail_hook {
    my ($self) = @_;

    # Call parent post_fail_hook to collect logs on failure
    $self->SUPER::post_fail_hook;
    # Ensure guests remain in a consistent state also on failure
    reset_guest($_, $MAC_PREFIX) foreach (keys %virt_autotest::common::guests);
}

1;
