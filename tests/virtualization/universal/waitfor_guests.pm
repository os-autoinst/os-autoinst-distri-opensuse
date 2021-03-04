# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: libvirt-client
# Summary: Wait for guests so they finish the installation
# Maintainer: Pavel Dostál <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub ensure_reboot_policy {
    my $guest = shift;
    my $xml   = "$guest.xml";
    assert_script_run("virsh dumpxml $guest > $xml");
    assert_script_run("sed 's!.*<on_reboot>.*</on_reboot>!<on_reboot>restart</on_reboot>!' -i $xml");
    assert_script_run("virt-xml-validate $xml");
    assert_script_run("virsh define $xml");
    # Check if the reboot policy is applied correctly
    assert_script_run("virsh dumpxml $guest | grep on_reboot | grep restart");
}

sub add_pci_bridge {
    my $guest = shift;
    my $xml   = "$guest.xml";

    assert_script_run("virsh dumpxml $guest > $xml");

    # There are two different approaches, one for q35 and one for i440fx machine type
    if (script_run("grep machine '$xml' | grep 'i440fx'") == 0) {
        # on i440fx add a pci-bridge:
        # "<controller type='pci' model='pci-bridge'/>"

        # Skip if a pci-bridge is already present
        return if (script_run("cat $xml | grep 'controller' | grep 'pci-bridge'") == 0);

        my $regex     = '<controller type=.pci. .*model=.pci-root..*>';
        my $addbefore = '<controller type="pci" model="pci-bridge"/>';
        # the add_before.sh script inserts a given line before the line matching the given regex
        assert_script_run("virsh dumpxml $guest | /root/add_before.sh '$regex' '$addbefore' > $xml");
        upload_logs("$xml");

        # Check if settings are applied correctly in the new xml
        assert_script_run("cat $xml | grep 'controller' | grep 'pci-root'");
        assert_script_run("cat $xml | grep 'controller' | grep 'pci-bridge'");

        # Apply xml settings to VM. Note: They will be applied after reboot.
        assert_script_run("virt-xml-validate $xml");
        assert_script_run("virsh define $xml");

    } elsif (script_run("grep machine '$xml' | grep 'q35'") == 0) {
        # On q35 add a pcie-root-port and a pcie-to-pci bridge

        # Skip if a pcie-to-pci-bridge is already present
        return if (script_run("cat $xml | grep 'controller' | grep 'pcie-to-pci-bridge'") == 0);

        my $regex     = '<controller type=.pci. .*model=.pcie-root..*>';
        my $addbefore = '<controller type="pci" model="pcie-root-port"/><controller type="pci" model="pcie-to-pci-bridge"/>';
        # the add_before.sh script inserts a given line before the line matching the given regex
        assert_script_run("virsh dumpxml $guest | /root/add_before.sh '$regex' '$addbefore' > $xml");
        upload_logs("$xml");

        # Check if settings are applied correctly in the xml
        assert_script_run("cat $xml | grep 'controller' | grep 'pcie-root-port'");
        assert_script_run("cat $xml | grep 'controller' | grep 'pcie-to-pci-bridge'");

        # Apply xml settings to VM. Note: They will be applied after reboot.
        assert_script_run("virt-xml-validate $xml");
        assert_script_run("virsh define $xml");

    } elsif (is_xen_host() && is_pv_guest($guest)) {
        # We're skipping to add an additional bridge on xen
    } else {
        my $msg = "Unknown machine type";
        record_soft_failure($msg);
    }
}

# Upload xml definitions of all guests
sub upload_machine_definitions {
    foreach my $guest (keys %virt_autotest::common::guests) {
        my $xml = "$guest.xml";
        assert_script_run("virsh dumpxml $guest | tee $xml");
        upload_logs("$xml");
    }
}

sub run {
    my $self = shift;
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    $self->select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;

    # Fill the current pairs of hostname & address into /etc/hosts file
    assert_script_run 'virsh list --all';
    add_guest_to_hosts $_, $virt_autotest::common::guests{$_}->{ip} foreach (keys %virt_autotest::common::guests);
    assert_script_run "cat /etc/hosts";

    # Wait for guests to finish installation
    script_run("wait", timeout => 1200);
    #script_retry("! ps x | grep -v 'grep' | grep 'virt-install'", retry => 120, delay => 10);
    # Unfortunately this doesn't cover the second step of the installation, where ssh is available
    script_run("sleep 600", timeout => 660);    # XXX No idea yet how to prevent this sleep :-(
    start_guests();
    record_info("guests installed", "Guest installation completed");
    wait_guest_online($_, 120) foreach (keys %virt_autotest::common::guests);

    # Adding the PCI bridges requires the guests to be shutdown
    record_info("shutdown guests", "Shutting down all guests");
    shutdown_guests();

    # Download helper script for adding PCI bridge. add_before adds a line before a given regex.
    # Usage: add_before REGEX LINE_TO_ADD
    assert_script_run('curl -v -o /root/add_before.sh ' . data_url('virtualization/add_before.sh'));
    assert_script_run('chmod 0755 /root/add_before.sh');
    ## Add a PCIe root port and a PCIe to PCI bridge for hotplugging
    add_pci_bridge("$_") foreach (keys %virt_autotest::common::guests);

    ## Ensure the reboot policy is set to 'restart'. This needs to happen on shutdown guest
    # Do a shutdown and start here because some guests might not reboot because of the on_reboot=destroy policy
    ensure_reboot_policy("$_") foreach (keys %virt_autotest::common::guests);
    upload_machine_definitions();

    record_info("Starting guests", "Starting all guests");
    start_guests();

    # Check that guests are online so we can continue and setup them
    ensure_online $_, skip_ssh => 1, ping_delay => 45 foreach (keys %virt_autotest::common::guests);

    # All guests should be now installed and running
    assert_script_run('virsh list --all');
    wait_still_screen 1;
}

sub post_fail_hook {
    my ($self) = @_;
    collect_virt_system_logs();
    $self->SUPER::post_fail_hook;
}

1;
