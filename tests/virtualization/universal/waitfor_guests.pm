# XEN regression tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-client
# Summary: Wait for guests so they finish the installation
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

# Open vnc and take screenshot of guests
sub screenshot_vnc_guests {
    foreach my $guest (keys %virt_autotest::common::guests) {
        # Wait for virt-viewer to fully connect and display VNC stream
        enter_cmd "virt-viewer -f $guest & sleep 21 && killall virt-viewer";
        sleep 19;
        record_info "$guest", "$guest screenshot";
        save_screenshot();
        sleep 6;
    }
}

sub run {
    my $self = shift;
    select_console('root-console');
    my @guests = keys %virt_autotest::common::guests;
    # Fill the current pairs of hostname & address into /etc/hosts file
    assert_script_run 'virsh list --all';
    add_guest_to_hosts $_, $virt_autotest::common::guests{$_}->{ip} foreach (@guests);
    assert_script_run "cat /etc/hosts";

    # Wait for guests to announce that installation is complete
    my $retry = 35;
    my $count = 0;
    while ($count++ < $retry) {
        my @wait_guests = ();
        foreach my $guest (@guests) {
            if (script_run("test -f /tmp/guests_ip/$guest") ne 0) {
                push(@wait_guests, $guest);
            }
        }
        # if all guests are install exit the loop
        last if @wait_guests == 0;
        sleep 120;
        # if retry number is reached the test will fail
        if ($count == $retry) {
            record_info("Failed: timeout", "Timeout installation for @wait_guests");
            die;
        }
    }
    record_info("All guests installed", "Guest installation completed");
    if (is_sle('>15') && get_var("KVM")) {
        # Adding the PCI bridges requires the guests to be shutdown
        record_info("shutdown guests", "Shutting down all guests");
        shutdown_guests();

        # Add a PCIe root port and a PCIe to PCI bridge for Q35 machine
        if (is_sle('<15-SP4')) {
            assert_script_run("virt-xml $_ --add-device --controller type=pci,index=11,model=pcie-to-pci-bridge") foreach (@guests);
        } else {
            assert_script_run("virt-xml $_ --add-device --controller type=pci,model=pcie-to-pci-bridge") foreach (@guests);
        }
        record_info("Starting guests", "Starting all guests");
        start_guests();
        ensure_online $_, skip_ssh => 1, ping_delay => 45 foreach (@guests);
    }
    assert_script_run('virsh list --all');
    wait_still_screen 1;
}

sub post_fail_hook {
    my ($self) = @_;
    screenshot_vnc_guests();
    collect_virt_system_logs();
    $self->SUPER::post_fail_hook;
}

1;
