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

# Summary: HOST bridge virtual network test:
#    - Create HOST bridge virtual network
#    - Confirm HOST bridge virtual network
#    - Destroy HOST bridge virtual network
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

our $virt_host_bridge = 'br0';
our $based_guest_dir  = 'tmp';
sub run_test {
    my ($self) = @_;

    #Prepare VM HOST SERVER Network Interface Configuration
    #for libvirt virtual network testing
    virt_autotest::virtual_network_utils::prepare_network($virt_host_bridge, $based_guest_dir);

    #Download libvirt host bridge virtual network configuration file
    my $vnet_host_bridge_cfg_name = "vnet_host_bridge.xml";
    virt_autotest::virtual_network_utils::download_network_cfg($vnet_host_bridge_cfg_name);

    #Create HOST BRIDGE NETWORK
    assert_script_run("sed -i -e 's/BRI/$virt_host_bridge/' $vnet_host_bridge_cfg_name");
    assert_script_run("virsh net-create $vnet_host_bridge_cfg_name");
    assert_script_run("virsh net-list --all|grep vnet_host_bridge");
    save_screenshot;
    upload_logs "$vnet_host_bridge_cfg_name";
    assert_script_run("rm -rf $vnet_host_bridge_cfg_name");

    my ($mac, $model, $affecter, $exclusive);
    my $gate = script_output "ip r s | grep 'default via ' | cut -d' ' -f3";
    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "HOST BRIDGE NETWORK for $guest";

        if (is_sle('=11-sp4') && (get_var('XEN') || check_var('SYSTEM_ROLE', 'xen') || check_var('HOST_HYPERVISOR', 'xen'))) {
            $affecter  = "--persistent";
            $exclusive = "--live --persistent";
        } else {
            $affecter  = "";
            $exclusive = "--current";
        }

        $mac   = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        $model = (get_var('XEN') || check_var('SYSTEM_ROLE', 'xen') || check_var('HOST_HYPERVISOR', 'xen')) ? 'netfront' : 'virtio';

        assert_script_run("virsh attach-interface $guest network vnet_host_bridge --model $model --mac $mac --live $affecter", 60);

        my $net = is_sle('=11-sp4') ? 'br123' : 'vnet_host_bridge';
        test_network_interface($guest, mac => $mac, gate => $gate, net => $net);

        assert_script_run("virsh detach-interface $guest bridge --mac $mac $exclusive");
    }

    #Destroy HOST BRIDGE NETWORK
    assert_script_run("virsh net-destroy vnet_host_bridge");
    save_screenshot;

    #Restore Network setting after finished HOST BRIDGE NETWORK Test
    virt_autotest::virtual_network_utils::restore_network($virt_host_bridge, $based_guest_dir);
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

    #Restore Network setting
    virt_autotest::virtual_network_utils::restore_network($virt_host_bridge, $based_guest_dir);
}

1;
