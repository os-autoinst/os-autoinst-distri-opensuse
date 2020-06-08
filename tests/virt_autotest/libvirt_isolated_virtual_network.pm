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
use version_utils 'is_sle';

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

    my ($mac, $model, $affecter, $exclusive);
    my $gate = '192.168.127.1';    # This host exists but should not work as a gate in the ISOLATED NETWORK
    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "ISOLATED NETWORK for $guest";

        if (is_sle('=11-sp4') && (get_var('XEN') || check_var('SYSTEM_ROLE', 'xen') || check_var('HOST_HYPERVISOR', 'xen'))) {
            $affecter  = "--persistent";
            $exclusive = "bridge --live --persistent";
        } else {
            $affecter  = "";
            $exclusive = "network --current";
        }

        $mac   = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        $model = (get_var('XEN') || check_var('SYSTEM_ROLE', 'xen') || check_var('HOST_HYPERVISOR', 'xen')) ? 'netfront' : 'virtio';

        assert_script_run("virsh attach-interface $guest network vnet_isolated --model $model --mac $mac --live $affecter", 60);

        my $net = is_sle('=11-sp4') ? 'br123' : 'vnet_isolated';
        test_network_interface($guest, mac => $mac, gate => $gate, isolated => 1, net => $net);

        assert_script_run("virsh detach-interface $guest --mac $mac $exclusive");
    }

    #Destroy ISOLATED NETWORK
    assert_script_run("virsh net-destroy vnet_isolated");
    save_screenshot;

    #Restore Guest systems
    virt_autotest::virtual_network_utils::restore_guests();

    #After finished all virtual network test, need to restore file /etc/hosts from backup
    virt_autotest::virtual_network_utils::hosts_restore();

    #Skip restart network service due to bsc#1166570
    #Restart network service
    #virt_autotest::virtual_network_utils::restart_network();
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
