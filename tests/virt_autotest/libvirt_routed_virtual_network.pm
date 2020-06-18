# SUSE's openQA tests
#
# Copyright (C) 2019-2020 SUSE LLC
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
use version_utils 'is_sle';

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

    my ($mac1, $mac2, $model1, $model2, $affecter, $exclusive);
    my $target1 = '192.168.130.1';
    my $target2 = '192.168.129.1';
    my $gate1   = '192.168.129.1';
    my $gate2   = '192.168.130.1';
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

        if (is_sle('=11-sp4') && (get_var('XEN') || check_var('SYSTEM_ROLE', 'xen') || check_var('HOST_HYPERVISOR', 'xen'))) {
            $affecter  = "--persistent";
            $exclusive = "bridge --live --persistent";
        } else {
            $affecter  = "";
            $exclusive = "network --current";
        }

        #figure out that used with virtio as the network device model during
        #attach-interface via virsh worked for all sles guest
        $mac1   = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        $model1 = (get_var('XEN') || check_var('SYSTEM_ROLE', 'xen') || check_var('HOST_HYPERVISOR', 'xen')) ? 'netfront' : 'virtio';

        assert_script_run("virsh attach-interface $guest network vnet_routed --model $model1 --mac $mac1 --live $affecter", 60);

        $mac2   = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        $model2 = (get_var('XEN') || check_var('SYSTEM_ROLE', 'xen') || check_var('HOST_HYPERVISOR', 'xen')) ? 'netfront' : 'virtio';

        assert_script_run("virsh attach-interface $guest.clone network vnet_routed_clone --model $model2 --mac $mac2 --live $affecter", 60);

        #Wait for guests attached interface from virtual routed network
        sleep 30;
        my $net1 = is_sle('=11-sp4') ? 'br123' : 'vnet_routed';
        test_network_interface("$guest", mac => $mac1, gate => $gate1, routed => 1, target => $target1, net => $net1);
        my $net2 = is_sle('=11-sp4') ? 'br123' : 'vnet_routed_clone';
        test_network_interface("$guest.clone", mac => $mac2, gate => $gate2, routed => 1, target => $target2, net => $net2);

        assert_script_run("virsh detach-interface $guest --mac $mac1 $exclusive");
        assert_script_run("virsh detach-interface $guest.clone --mac $mac2 $exclusive");

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

    #Upload debug log
    virt_autotest::virtual_network_utils::upload_debug_log();

    #Restart libvirtd service
    virt_autotest::virtual_network_utils::restart_libvirtd();

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();

    #Restore br123 for virt_autotest
    virt_autotest::virtual_network_utils::restore_standalone();

    #Restore Guest systems
    virt_autotest::virtual_network_utils::restore_guests();
}

1;
