# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Routed virtual network test:
#    - Create Routed virtual network
#    - Confirm Routed virtual network
#    - Destroy Routed virtual network
# Maintainer: Leon Guo <xguo@suse.com>

use base "virt_feature_test_base";
use virt_utils;
use set_config_as_glue;
use virt_autotest::virtual_network_utils;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run_test {
    my ($self) = @_;
    my @guests = @{get_var_array("TEST_GUESTS")};

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
    my $gate1 = '192.168.129.1';
    my $gate2 = '192.168.130.1';
    foreach my $guest (@guests) {
        record_info "$guest", "ROUTED NETWORK for $guest";
        #NOTE
        #There will be two guests in two different routed networks so then the
        #host can route their traffic to confirm libvirt routed network
        assert_script_run("virsh dumpxml $guest > $guest.clone");
        assert_script_run("virsh destroy $guest || (virsh list --state-shutoff | grep $guest)");
        assert_script_run("virsh undefine $guest || virsh undefine $guest --keep-nvram");
        assert_script_run("virsh define $guest.clone");
        assert_script_run("rm -rf $guest.clone");
        assert_script_run("virt-clone -o $guest -n $guest.clone -f /var/lib/libvirt/images/$guest.clone");
        assert_script_run("virsh start $guest");
        ensure_online $guest, skip_network => 1;
        assert_script_run("virsh start $guest.clone");
        ensure_online "$guest.clone", skip_network => 1;

        if (is_sle('=11-sp4') && is_xen_host) {
            $affecter = "--persistent";
            $exclusive = "bridge --live --persistent";
        } else {
            $affecter = "";
            $exclusive = "network --current";
        }

        #figure out that used with virtio as the network device model during
        #attach-interface via virsh worked for all sles guest
        $mac1 = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        $model1 = (is_xen_host) ? 'netfront' : 'virtio';

        #Check guest loaded kernel module before attach interface to guest system
        check_guest_module("$guest", module => "acpiphp");
        assert_script_run("virsh attach-interface $guest network vnet_routed --model $model1 --mac $mac1 --live $affecter", 60);
        #Wait for attached interface and associated information to be populated and become stable
        die "Interface model:$model1 mac:$mac1 can not be attached to guest $guest successfully" if (script_retry("virsh domiflist $guest | grep vnet_routed | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"", delay => 30, retry => 10) ne 0);

        $mac2 = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        $model2 = (is_xen_host) ? 'netfront' : 'virtio';

        #Check guest loaded kernel module before attach interface to guest system
        check_guest_module("$guest.clone", module => "acpiphp");
        assert_script_run("virsh attach-interface $guest.clone network vnet_routed_clone --model $model2 --mac $mac2 --live $affecter", 60);
        #Wait for attached interface and associated information to be populated and become stable
        die "Interface model:$model2 mac:$mac2 can not be attached to guest $guest.clone successfully" if (script_retry("virsh domiflist $guest.clone | grep vnet_routed_clone | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"", delay => 30, retry => 10) ne 0);

        my $net1 = is_sle('=11-sp4') ? 'br123' : 'vnet_routed';
        test_network_interface("$guest", mac => $mac1, gate => $gate1, routed => 1, target => $target1, net => $net1);
        my $net2 = is_sle('=11-sp4') ? 'br123' : 'vnet_routed_clone';
        test_network_interface("$guest.clone", mac => $mac2, gate => $gate2, routed => 1, target => $target2, net => $net2);

        assert_script_run("virsh detach-interface $guest --mac $mac1 $exclusive");
        assert_script_run("virsh detach-interface $guest.clone --mac $mac2 $exclusive");

        script_run "sed -i '/ $guest.clone /d' /etc/hosts";
        assert_script_run("virsh destroy $guest.clone");
        assert_script_run("virsh undefine $guest.clone || virsh undefine $guest.clone --keep-nvram");
        assert_script_run("rm -rf /var/lib/libvirt/images/$guest.clone");
    }
    #Destroy ROUTED NETWORK
    assert_script_run("virsh net-destroy vnet_routed");
    assert_script_run("virsh net-destroy vnet_routed_clone");
    save_screenshot;
}

sub post_fail_hook {
    my ($self) = @_;
    my @guests = @{get_var_array("TEST_GUESTS")};

    $self->SUPER::post_fail_hook;

    #Restart libvirtd service
    virt_autotest::utils::restart_libvirtd();

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();

    #Restore br123 for virt_autotest
    virt_autotest::virtual_network_utils::restore_standalone();

    #Restore Guest systems
    virt_autotest::virtual_network_utils::restore_guests(@guests);
}

1;
