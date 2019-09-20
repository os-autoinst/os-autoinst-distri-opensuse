# SUSE's openQA tests
#
# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Isolated virtual network test:
#    - Create Isolated virtual network
#    - Confirm Isolated virtual network
#    - Destroy Isolated virtual network
# Maintainer: Leon Guo <xguo@suse.com>

use base "virt_feature_test_base";
use virt_utils;
use set_config_as_glue;
use virt_autotest::virtual_network_utils;
use strict;
use warnings;
use testapi;
use utils;

sub run_test {
    my ($self) = @_;

    #Download libvirt isolated virtual network configuration file
    my $vnet_isolated_cfg_name = "vnet_isolated.xml";
    virt_autotest::virtual_network_utils::download_network_cfg($vnet_isolated_cfg_name);

    #Create ISOLATED NETWORK
    assert_script_run("virsh net-create vnet_isolated.xml");
    save_screenshot;
    upload_logs "vnet_isolated.xml";
    assert_script_run("rm -rf vnet_isolated.xml");

    my $gi_vnet_isolated;
    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "ISOLATED NETWORK for $guest";
        assert_script_run("virsh attach-interface $guest network vnet_isolated --live");
        #Get the Guest IP Address from ISOLATED NETWORK
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            my $mac_isolated = script_output("virsh domiflist $guest | grep vnet_isolated | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"");
            script_retry "ip neigh | grep $mac_isolated | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 90, retry => 9, timeout => 90;
            $gi_vnet_isolated = script_output("ip neigh | grep $mac_isolated | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
        }
        else {
            script_retry "virsh net-dhcp-leases vnet_isolated | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 90, retry => 9, timeout => 90;
            $gi_vnet_isolated = script_output("virsh net-dhcp-leases vnet_isolated | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
        }
        #Confirm ISOLATED NETWORK
        assert_script_run("! ssh root\@$gi_vnet_isolated 'ping -c2 -W1 openqa.suse.de'");
        save_screenshot;
        assert_script_run("virsh detach-interface $guest network --current");
    }
    #Destroy ISOLATED NETWORK
    assert_script_run("virsh net-destroy vnet_isolated");
    save_screenshot;

    #Restore br123 for virt_autotest
    virt_autotest::virtual_network_utils::restore_standalone();

    #Restore Guest systems
    virt_autotest::virtual_network_utils::restore_guests();

    #Restart libvirtd service
    virt_autotest::virtual_network_utils::restart_libvirtd();

    #Restart network service
    virt_autotest::virtual_network_utils::restart_network();
}

sub post_fail_hook {
    my ($self) = @_;

    #Restart libvirtd service
    virt_autotest::virtual_network_utils::restart_libvirtd();

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();

    #Restore br123 for virt_autotest
    virt_autotest::virtual_network_utils::restore_standalone();

    #Restore Guest systems
    virt_autotest::virtual_network_utils::restore_guests();

    #Upload debug log
    virt_autotest::virtual_network_utils::upload_debug_log();
}

1;
