# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: NAT based virtual network test:
#    - Define NAT based virtual network
#    - Confirm NAT based virtual network
#    - Destroy NAT based virtual network
# Maintainer: Leon Guo <xguo@suse.com>, qe-virt@suse.de

use base "virt_feature_test_base";
use virt_utils;
use virt_autotest::virtual_network_utils;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_alp);

sub run_test {
    my ($self) = @_;

    #Download libvirt host bridge virtual network configuration file
    my $vnet_nated_cfg_name = "vnet_nated.xml";
    virt_autotest::virtual_network_utils::download_network_cfg($vnet_nated_cfg_name);

    die "The default(NAT BASED NETWORK) virtual network does not exist" if (script_run('virsh net-list --all | grep default') != 0 && !is_alp);

    #Create NAT BASED NETWORK
    assert_script_run("virsh net-create vnet_nated.xml");
    save_screenshot;
    upload_logs "vnet_nated.xml";
    assert_script_run("rm -rf vnet_nated.xml");

    my ($mac, $model, $affecter, $exclusive, $skip_type);
    my $gate = '192.168.128.1';
    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "NAT BASED NETWORK for $guest";
        #Just only 15-SP5 PV guest system have a rebooting problem due to bsc#1206250
        $skip_type = ($guest =~ m/sles-15-sp5-64-pv-def-net/i) ? 'skip_ping' : 'skip_network';
        #Ensures the given guests is started and fixes some common network issues
        ensure_online $guest, $skip_type => 1;
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
        assert_script_run("virsh attach-interface $guest network vnet_nated --model $model --mac $mac --live $affecter", 60);

        my $net = is_sle('=11-sp4') ? 'br123' : 'vnet_nated';
        test_network_interface($guest, mac => $mac, gate => $gate, net => $net);

        assert_script_run("virsh detach-interface $guest --mac $mac $exclusive");
    }

    #Destroy NAT BASED NETWORK
    assert_script_run("virsh net-destroy vnet_nated");
    save_screenshot;
}

sub post_fail_hook {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;

    #Restart libvirtd service
    # Note: TBD for modular libvirt. See poo#129086 for detail.
    virt_autotest::utils::restart_libvirtd() if is_monolithic_libvirtd;

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();

    #Restore default(NATed Network)
    virt_autotest::virtual_network_utils::restore_libvirt_default();

    #Restore br123 for virt_autotest
    virt_autotest::virtual_network_utils::restore_standalone();

    #Restore Guest systems
    virt_autotest::virtual_network_utils::restore_guests();
}

1;
