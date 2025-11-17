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

sub access_vm_profiles {
    record_info("Vm profile accessibility check...");
    foreach my $guest (values %virt_autotest::common::guests) {
        record_info("VM profile accessibility", $guest->{name});
        my $_cmd = "curl -v -L -f " . $guest->{autoyast};
        script_run("$_cmd");
    }
}

sub run {
    my $self = shift;
    select_console('root-console');
    my @guests = keys %virt_autotest::common::guests;

    # Wait for guests to announce that installation is complete
    my $retry = 35;
    my $count = 0;

    # List of guests expected to complete AutoYaST installation stage 1 and 2
    my @wait_stage_1_install = @guests;
    my @wait_stage_2_install = @guests;

    # When SEV_ES guests are rebooted by AutoYast installation in the end of stage 1
    # they will stay in shutdown state, we have to start the guest to continue with stage 2
    if (check_var('ENABLE_SEV_ES', '1')) {
        record_info("Installation Stage 1", "Waiting for SEV-ES guests to finish AutoYast stage 1.");

        while (@wait_stage_1_install && $count++ < $retry) {
            @wait_stage_1_install = grep { script_run("virsh list --name | grep -w $_") == 0 } @wait_stage_1_install;

            # If all guests completed stage 1 of installation exit the loop
            last unless @wait_stage_1_install;
            sleep 120;
        }

        if (@wait_stage_1_install) {
            record_info("Failed: Stage 1 install timeout", "Timeout waiting for SEV-ES AutoYast stage 1: @wait_stage_1_install");
            die "Stage 1 installation timeout";
        }

        record_info("Stage 1 AutoYast completed", "All SEV-ES guests have completed installation stage 1 and are shutdown.");
        foreach my $guest (@guests) {
            script_run("virsh start $guest");
        }

        record_info("Stage 2 start", "Starting SEV-ES guests to continue with stage 2 of installation.");
    }

    while ($count++ < $retry) {
        @wait_stage_2_install = grep { script_run("test -f /tmp/guests_ip/$_") != 0 } @wait_stage_2_install;

        # If all guests completed stage 2 of installation exit the loop
        last if @wait_stage_2_install == 0;
        sleep 120;
        # If retry number is reached the test will fail
        if ($count == $retry) {
            record_info("Failed: timeout", "Timeout installation for @wait_stage_2_install");
            die;
        }
    }

    # Update guests hash with IP/macaddress and add guests to /etc/hosts
    foreach my $guest (@guests) {
        my $guest_ip = script_output("cat /tmp/guests_ip/$guest");
        # Update the guests hash with the current IP address for migration testing
        $virt_autotest::common::guests{$guest}{ip} = "$guest_ip";
        # Update the guests hash with the guest macaddress
        my $guest_mac = script_output("virsh domiflist $guest | awk 'NR>2 {print \$5}'");
        $virt_autotest::common::guests{$guest}{macaddress} = "$guest_mac";
        record_info("$guest networking", "$guest IP: $guest_ip MAC: $guest_mac");
        # Fill the current pairs of hostname & address to the /etc/hosts file
        add_guest_to_hosts($guest, $guest_ip);
    }

    # Check address information in /etc/hosts file
    assert_script_run 'virsh list --all';
    assert_script_run "cat /etc/hosts";

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
    access_vm_profiles();
    collect_virt_system_logs();
    $self->SUPER::post_fail_hook;
}

1;
