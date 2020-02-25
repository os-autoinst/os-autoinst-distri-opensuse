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

our $virt_host_bridge = 'br0';
sub run_test {
    my ($self) = @_;

    #Prepare VM HOST SERVER Network Interface Configuration
    #for libvirt virtual network testing
    virt_autotest::virtual_network_utils::prepare_network($virt_host_bridge);

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

    my $gi_host_bridge = '';
    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "HOST BRIDGE NETWORK for $guest";
        #figure out that used with virtio as the network device model during
        #attach-interface via virsh worked for all sles guest
        assert_script_run("virsh attach-interface $guest network vnet_host_bridge --model virtio --live");
        #Get the Guest IP Address from HOST BRIDGE NETWORK
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            my $mac_host_bridge = script_output("virsh domiflist $guest | grep vnet_host_bridge|grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"");
            script_retry "ip neigh | grep $mac_host_bridge | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 60, retry => 6, timeout => 60;
            $gi_host_bridge = script_output("ip neigh | grep $mac_host_bridge | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
        }
        else {
            script_retry "virsh domifaddr $guest --source arp | grep vnet0 | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 150, retry => 15, timeout => 150;
            $gi_host_bridge = script_output("virsh domifaddr $guest --source arp | grep vnet0| grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
        }
        #Confirm HOST BRIDGE NETWORK
        assert_script_run("ssh root\@$gi_host_bridge 'ping -c2 -W1 openqa.suse.de'", 60);
        save_screenshot;
        assert_script_run("virsh detach-interface $guest bridge --current");
    }
    #Destroy HOST BRIDGE NETWORK
    assert_script_run("virsh net-destroy vnet_host_bridge");
    save_screenshot;

    #Restore Network setting
    virt_autotest::virtual_network_utils::restore_network($virt_host_bridge);
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
    virt_autotest::virtual_network_utils::restore_network($virt_host_bridge);
}

1;
