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

# Summary: Routed virtual network test:
#    - Create Routed virtual network
#    - Confirm Routed virtual network
#    - Destroy Routed virtual network
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

    #Download libvirt routed virtual network configuration files
    my $vnet_routed_cfg_name = "vnet_routed.xml";
    virt_autotest::virtual_network_utils::download_network_cfg($vnet_routed_cfg_name);

    my $vnet_routed_clone_cfg_name = "vnet_routed_clone.xml";
    virt_autotest::virtual_network_utils::download_network_cfg($vnet_routed_clone_cfg_name);

    #Create ROUTED NETWORK
    assert_script_run("virsh net-create vnet_routed.xml");
    upload_logs "vnet_routed.xml";
    assert_script_run("virsh net-create vnet_routed_clone.xml");
    upload_logs "vnet_routed_clone.xml";
    assert_script_run("rm -rf vnet_routed.xml vnet_routed_clone.xml");

    my $gi_vnet_routed;
    my $gi_vnet_routed_clone;
    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "ROUTED NETWORK for $guest";
        #NOTE
        #There will be two guests in two different routed networks so then the
        #host can route their traffic to confirm libvirt routed network
        assert_script_run("virsh dumpxml $guest > $guest.clone");
        assert_script_run("virsh destroy $guest");
        assert_script_run("virsh undefine $guest");
        assert_script_run("virsh define $guest.clone");
        assert_script_run("rm -rf $guest.clone");
        assert_script_run("virt-clone -o $guest -n $guest.clone -f /var/lib/libvirt/images/$guest.clone");
        assert_script_run("virsh start $guest");
        assert_script_run("virsh start $guest.clone");
        assert_script_run("virsh attach-interface $guest network vnet_routed --live");
        assert_script_run("virsh attach-interface $guest.clone network vnet_routed_clone --live");
        #Get the Guest IP Address from ROUTED NETWORK
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            my $mac_routed = script_output("virsh domiflist $guest | grep vnet_routed | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"");
            script_retry "ip neigh | grep $mac_routed | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 60, retry => 6, timeout => 60;
            $gi_vnet_routed = script_output("ip neigh | grep $mac_routed | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
            my $mac_routed_clone = script_output("virsh domiflist $guest.clone | grep vnet_routed_clone | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"");
            script_retry "ip neigh | grep $mac_routed_clone | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 60, retry => 6, timeout => 60;
            $gi_vnet_routed_clone = script_output("ip neigh | grep $mac_routed_clone | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
        }
        else {
            script_retry "virsh net-dhcp-leases vnet_routed | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 60, retry => 6, timeout => 60;
            $gi_vnet_routed = script_output("virsh net-dhcp-leases vnet_routed | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
            script_retry "virsh net-dhcp-leases vnet_routed_clone | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 60, retry => 6, timeout => 60;
            $gi_vnet_routed_clone = script_output("virsh net-dhcp-leases vnet_routed_clone | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
        }
        #Confirm ROUTED NETWORK
        assert_script_run("ssh root\@$gi_vnet_routed 'traceroute $gi_vnet_routed_clone'", 60);
        save_screenshot;
        assert_script_run("ssh root\@$gi_vnet_routed_clone 'traceroute $gi_vnet_routed'", 60);
        save_screenshot;
        assert_script_run("virsh detach-interface $guest network --current");
        assert_script_run("virsh detach-interface $guest.clone network --current");
        assert_script_run("virsh destroy $guest.clone");
        assert_script_run("virsh undefine $guest.clone");
        assert_script_run("rm -rf /var/lib/libvirt/images/$guest.clone");
    }
    #Destroy ROUTED NETWORK
    assert_script_run("virsh net-destroy vnet_routed");
    assert_script_run("virsh net-destroy vnet_routed_clone");
    save_screenshot;
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
