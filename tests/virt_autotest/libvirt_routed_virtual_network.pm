# SUSE's openQA tests
#
# Copyright 2019-2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Routed virtual network test:
#    - Create Routed virtual network
#    - Confirm Routed virtual network
#    - Destroy Routed virtual network
# Maintainer: Leon Guo <xguo@suse.com>, qe-virt@suse.de

use base "virt_feature_test_base";
use virt_utils;
use virt_autotest::virtual_network_utils;
use virt_autotest::utils;
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

    #Stop named.service, refer to poo#175287
    systemctl("stop named.service") if (is_sle('=15-SP7') && check_var('VIRT_AUTOTEST', 1) && !get_var('VIRT_UNIFIED_GUEST_INSTALL'));
    #Create ROUTED NETWORK
    assert_script_run("virsh net-create vnet_routed.xml");
    assert_script_run("virsh net-create vnet_routed_clone.xml");
    save_screenshot;
    upload_logs "vnet_routed.xml";
    upload_logs "vnet_routed_clone.xml";
    assert_script_run("rm -rf vnet_routed.xml vnet_routed_clone.xml");
    #Resume named.service, refer to poo#175287
    systemctl("start named.service") if (is_sle('=15-SP7') && check_var('VIRT_AUTOTEST', 1) && !get_var('VIRT_UNIFIED_GUEST_INSTALL'));

    my ($mac1, $mac2, $target1, $target2, $gateway1, $gateway2);
    $target1 = '192.168.130.1';
    $target2 = '192.168.129.1';
    $gateway1 = '192.168.129.1';
    $gateway2 = '192.168.130.1';
    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "ROUTED NETWORK for $guest";
        my $data = virt_autotest::virtual_network_utils::get_virtual_network_data($guest, net => "vnet_routed", exclusive => "network --current");
        #NOTE
        #There will be two guests in two different routed networks so then the
        #host can route their traffic to confirm libvirt routed network
        assert_script_run("virsh dumpxml $guest > $guest.clone");
        assert_script_run("virsh destroy $guest || (virsh list --state-shutoff | grep $guest)");
        assert_script_run("virsh undefine $guest || virsh undefine $guest --keep-nvram");
        assert_script_run("virsh define $guest.clone");
        assert_script_run("rm -rf $guest.clone");
        record_info "Clone a virtual machine from $guest";
        #setup a timeout value to clone a given guest system,
        #refer to poo#124107 for more details
        assert_script_run("virt-clone -o $guest -n $guest.clone -f /var/lib/libvirt/images/$guest.clone", 360);
        assert_script_run("virsh start $guest");
        ensure_online $guest, skip_network => 1;
        assert_script_run("virsh start $guest.clone");
        ensure_online "$guest.clone", skip_network => 1;

        #figure out that used with virtio as the network device model during
        #attach-interface via virsh worked for all sles guest
        $mac1 = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);

        #Check guest loaded kernel module before attach interface to guest system
        check_guest_module("$guest", module => "acpiphp");
        assert_script_run("virsh attach-interface $guest network vnet_routed --model $data->{model} --mac $mac1 --live $data->{affecter}", 60);
        #Wait for attached interface and associated information to be populated and become stable
        die "Interface model:$data->{model} mac:$mac1 can not be attached to guest $guest successfully" if (script_retry("virsh domiflist $guest | grep vnet_routed | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"", delay => 30, retry => 10) ne 0);

        $mac2 = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        #Check guest loaded kernel module before attach interface to guest system
        check_guest_module("$guest.clone", module => "acpiphp");
        assert_script_run("virsh attach-interface $guest.clone network vnet_routed_clone --model $data->{model} --mac $mac2 --live $data->{affecter}", 60);
        #Wait for attached interface and associated information to be populated and become stable
        die "Interface model:$data->{model} mac:$mac2 can not be attached to guest $guest.clone successfully" if (script_retry("virsh domiflist $guest.clone | grep vnet_routed_clone | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"", delay => 30, retry => 10) ne 0);

        test_network_interface("$guest", mac => $mac1, gateway => $gateway1, routed => 1, target => $target1, net => $data->{net});
        test_network_interface("$guest.clone", mac => $mac2, gateway => $gateway2, routed => 1, target => $target2, net => "vnet_routed_clone");

        assert_script_run("virsh detach-interface $guest --mac $mac1 $data->{exclusive}");
        assert_script_run("virsh detach-interface $guest.clone --mac $mac2 $data->{exclusive}");

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

    $self->SUPER::post_fail_hook;

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();
}

1;
