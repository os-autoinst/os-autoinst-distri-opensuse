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

    # Show all guests
    assert_script_run 'virsh list --all';
    wait_still_screen 1;
    save_screenshot;

    # Install every defined guest
    create_guest $_, 'virt-install' foreach (values %virt_autotest::common::guests);

    ## Ensure every guest has <on_reboot>restart</on_reboot>
    assert_script_run('curl -v -o ensure_reboot_policy.sh ' . data_url('virtualization/ensure_reboot_policy.sh'));
    assert_script_run('chmod 0755 ensure_reboot_policy.sh');
    foreach my $guest (keys %virt_autotest::common::guests) {
        if (script_run("! ./ensure_reboot_policy.sh $guest") != 0) {
            record_soft_failure("$guest bsc#1153028\nSetting on_reboot=restart failed for $guest");
        }
    }
    ## Add a PCIe root port and a PCIe to PCI bridge for hotplugging
    assert_script_run('curl -v -o add_pcie_hotplugging.sh ' . data_url('virtualization/add_pcie_hotplugging.sh'));
    assert_script_run('chmod 0755 add_pcie_hotplugging.sh');
    foreach my $guest (keys %virt_autotest::common::guests) {
        if (script_run("./add_pcie_hotplugging $guest")) {
            record_soft_failure("Failed to add PCIe2PCI bridge for $guest\nThis prevents bsc#1175218");
        }
    }

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
