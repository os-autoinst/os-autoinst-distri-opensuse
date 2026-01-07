# SUSE's openQA tests
#
# Copyright 2019-2025 SUSE LLC
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
use testapi;
use utils;
use version_utils 'is_sle';

sub run_test {
    my ($self) = @_;

    #Download libvirt isolated virtual network configuration file
    my $vnet_isolated_cfg_name = "vnet_isolated.xml";
    virt_autotest::virtual_network_utils::download_network_cfg($vnet_isolated_cfg_name);

    #Stop named.service, refer to poo#175287
    systemctl("stop named.service") if (is_sle('=15-SP7') && check_var('VIRT_AUTOTEST', 1) && !get_var('VIRT_UNIFIED_GUEST_INSTALL'));
    #Create ISOLATED NETWORK
    assert_script_run("virsh net-create vnet_isolated.xml");
    save_screenshot;
    upload_logs "vnet_isolated.xml";
    assert_script_run("rm -rf vnet_isolated.xml");
    #Resume named.service, refer to poo#175287
    systemctl("start named.service") if (is_sle('=15-SP7') && check_var('VIRT_AUTOTEST', 1) && !get_var('VIRT_UNIFIED_GUEST_INSTALL'));

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "ISOLATED NETWORK for $guest";
        my $data = virt_autotest::virtual_network_utils::get_virtual_network_data($guest, gateway => "192.168.127.1", net => "vnet_isolated", exclusive => "network --current");
        #Ensures the given guests is started and fixes some common network issues
        ensure_online($guest, $data->{skip_type} => 1);
        save_screenshot;

        my $mac = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        #Check guest loaded kernel module before attach interface to guest system
        check_guest_module("$guest", module => "acpiphp");
        assert_script_run("virsh attach-interface $guest network vnet_isolated --model $data->{model} --mac $mac --live $data->{affecter}", 60);

        #Wait for guests attached interface from virtual isolated network
        sleep 30;
        test_network_interface($guest, mac => $mac, gateway => $data->{gateway}, isolated => 1, net => $data->{net});

        assert_script_run("virsh detach-interface $guest --mac $mac $data->{exclusive}");
    }

    #Destroy ISOLATED NETWORK
    assert_script_run("virsh net-destroy vnet_isolated");
    save_screenshot;

    #After finished all virtual network test, need to restore file /etc/hosts from backup
    virt_autotest::virtual_network_utils::hosts_restore();
    #TODO: VM IP changed
}

sub post_fail_hook {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();
}

1;
