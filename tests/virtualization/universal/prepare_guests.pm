# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: libvirt-client iputils nmap xen-tools
# Summary: Installation of HVM and PV guests
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

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

#my $sed = 's!<controller type=.pci. .*model=.pci-root..*/>!<controller type="pci" index="0" model="pci-root"/>\n    <controller type="pci" model="pci-bridge"/>!';
#assert_script_run("virsh dumpxml $guest | sed '$sed' > $xml");
        my $regex     = '<controller type=.pci. .*model=.pci-root..*>';
        my $addbefore = '<controller type="pci" model="pci-bridge"/>';
        # the add_before.sh script inserts a given line before the line matching the given regex
        assert_script_run("virsh dumpxml $guest | /root/add_before.sh '$regex' '$addbefore' > $xml");
        upload_logs("$xml");

        # Check if settings are applied correctly in the new xml
        assert_script_run("cat $xml | grep 'controller' | grep 'pci-root'");
        assert_script_run("cat $xml | grep 'controller' | grep 'pci-bridge'");

        # Apply xml settings to VM. Note: They will be applied after reboot.
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

        ## Note: tac reverses the input line by line.
        ## We replace the first line of the reversed input, and then reverse it again, so that effectively we are replacing the last occurance of </controller>
#my $sed = '0,/<\\/controller>/s//<controller type=\"pci\" model=\"pcie-to-pci-bridge\"\\/>\\n<controller type=\"pci\" model=\"pcie-root-port\"\\/>\\n<\\/controller>/';
#assert_script_run("virsh dumpxml $guest | tac | sed '$sed' | tac > $xml");

        # Check if settings are applied correctly in the xml
        assert_script_run("cat $xml | grep 'controller' | grep 'pcie-root-port'");
        assert_script_run("cat $xml | grep 'controller' | grep 'pcie-to-pci-bridge'");
    }

    # Apply xml settings to VM. Note: They will be applied after reboot.
    assert_script_run("virsh define $xml");
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Ensure additional package is installed
    zypper_call '-t in libvirt-client iputils nmap';

    assert_script_run "mkdir -p /var/lib/libvirt/images/xen/";

    if (is_sle('<=12-SP1')) {
        script_run "umount /home";
        assert_script_run qq(sed -i 's/\\/home/\\/var\\/lib\\/libvirt\\/images\\/xen/g' /etc/fstab);
        script_run "mount /var/lib/libvirt/images/xen/";
    }

    assert_script_run "curl -f -v " . data_url("virt_autotest/libvirtd.conf") . " >> /etc/libvirt/libvirtd.conf";
    systemctl 'restart libvirtd';

    if (script_run("virsh net-list --all | grep default") != 0) {
        assert_script_run "curl " . data_url("virt_autotest/default_network.xml") . " -o ~/default_network.xml";
        assert_script_run "virsh net-define --file ~/default_network.xml";
    }
    assert_script_run "virsh net-start default || true", 90;
    assert_script_run "virsh net-autostart default",     90;

    # Remove existing guests, if present. This is needed for debugging runs, when we skip the installation
    # and it will not hurt on a fresh hypervisor
    script_run('for i in `virsh list --name --all`; do virsh destroy $i; virsh undefine $i; done');

    # Helper script
    assert_script_run('curl -v -o /root/add_before.sh ' . data_url('virtualization/add_before.sh'));
    assert_script_run('chmod 0755 /root/add_before.sh');

    # Install guests
    create_guest($_, 'virt-install') foreach (values %virt_autotest::common::guests);

    ## Add a PCIe root port and a PCIe to PCI bridge for hotplugging
    add_pci_bridge("$_") foreach (keys %virt_autotest::common::guests);

    script_run 'history -a';
    script_run('cat ~/virt-install* | grep ERROR', 30);
    script_run('xl dmesg |grep -i "fail\|error" |grep -vi Loglevel') if (is_xen_host());

    collect_virt_system_logs();
}

sub post_fail_hook {
    my ($self) = @_;
    collect_virt_system_logs();
    $self->SUPER::post_fail_hook;
}

1;
