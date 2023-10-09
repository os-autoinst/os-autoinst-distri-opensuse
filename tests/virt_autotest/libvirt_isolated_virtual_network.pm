# SUSE's openQA tests
#
# Copyright 2019-2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Isolated virtual network test:
#    - Create Isolated virtual network
#    - Confirm Isolated virtual network
#    - Destroy Isolated virtual network
# Maintainer: Leon Guo <xguo@suse.com>, qe-virt@suse.de

use base "virt_feature_test_base";
use virt_utils;
use virt_autotest::virtual_network_utils;
use virt_autotest::utils;
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

    my ($mac, $model, $affecter, $exclusive, $skip_type);
    my $gate = '192.168.127.1';    # This host exists but should not work as a gate in the ISOLATED NETWORK
    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "ISOLATED NETWORK for $guest";
        #Just only 15-SP5 PV guest system have a rebooting problem due to bsc#1206250
        $skip_type = ($guest =~ m/sles-15-sp5-64-pv-def-net/i) ? 'skip_ping' : 'skip_network';
        #Ensures the given guests is started and fixes some common network issues
        ensure_online($guest, $skip_type => 1);
        save_screenshot;

        if (is_sle('=11-sp4') && is_xen_host) {
            $affecter = "--persistent";
            $exclusive = "bridge --live --persistent";
        } else {
            $affecter = "";
            $exclusive = "network --current";
        }

        $mac = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        $model = (is_xen_host) ? 'netfront' : 'virtio';

        #Check guest loaded kernel module before attach interface to guest system
        check_guest_module("$guest", module => "acpiphp");
        assert_script_run("virsh attach-interface $guest network vnet_isolated --model $model --mac $mac --live $affecter", 60);

        #Wait for guests attached interface from virtual isolated network
        sleep 30;
        my $net = is_sle('=11-sp4') ? 'br123' : 'vnet_isolated';
        test_network_interface($guest, mac => $mac, gate => $gate, isolated => 1, net => $net);

        assert_script_run("virsh detach-interface $guest --mac $mac $exclusive");
    }

    #Destroy ISOLATED NETWORK
    assert_script_run("virsh net-destroy vnet_isolated");
    save_screenshot;

    #After finished all virtual network test, need to restore file /etc/hosts from backup
    virt_autotest::virtual_network_utils::hosts_restore();
}

sub post_fail_hook {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();
}

1;
