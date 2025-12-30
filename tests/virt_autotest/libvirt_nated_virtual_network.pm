# SUSE's openQA tests
#
# Copyright 2019-2025 SUSE LLC
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
use testapi;
use utils;
use version_utils qw(is_sle);

sub run_test {
    my ($self) = @_;

    #Download libvirt host bridge virtual network configuration file
    my $vnet_nated_cfg_name = "vnet_nated.xml";
    virt_autotest::virtual_network_utils::download_network_cfg($vnet_nated_cfg_name);

    die "The default(NAT BASED NETWORK) virtual network does not exist" if (script_run('virsh net-list --all | grep default') != 0);

    #Stop named.service, refer to poo#175287
    systemctl("stop named.service") if (is_sle('=15-SP7') && check_var('VIRT_AUTOTEST', 1) && !get_var('VIRT_UNIFIED_GUEST_INSTALL'));
    #Create NAT BASED NETWORK
    assert_script_run("virsh net-create vnet_nated.xml");
    save_screenshot;
    upload_logs "vnet_nated.xml";
    assert_script_run("rm -rf vnet_nated.xml");
    if (is_sle('=15-SP7') && check_var('VIRT_AUTOTEST', 1) && !get_var('VIRT_UNIFIED_GUEST_INSTALL')) {
        #Resume named.service, refer to poo#175287
        systemctl("start named.service");
        #Enable the listen-on option in named.conf
        #For more details, refer to poo#177354
        if (get_required_var('TEST_SUITE_NAME') =~ m/(uefi|sev)/i) {
            my $named_conf_file = "/etc/named.conf";
            assert_script_run("sed -i 's/#listen-on/listen-on/' $named_conf_file");
            systemctl("restart named.service");
        }
    }

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "NAT BASED NETWORK for $guest";
        my $data = virt_autotest::virtual_network_utils::get_virtual_network_data($guest, gateway => "192.168.128.1", net => "vnet_nated", exclusive => "network --current");
        #Ensures the given guests is started and fixes some common network issues
        ensure_online $guest, $data->{skip_type} => 1;
        save_screenshot;

        my $mac = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        #Check guest loaded kernel module before attach interface to guest system
        check_guest_module("$guest", module => "acpiphp");
        assert_script_run("virsh attach-interface $guest network vnet_nated --model $data->{model} --mac $mac --live $data->{affecter}", 60);

        test_network_interface($guest, mac => $mac, gateway => $data->{gateway}, net => $data->{net});

        assert_script_run("virsh detach-interface $guest --mac $mac $data->{exclusive}");
    }

    #Destroy NAT BASED NETWORK
    assert_script_run("virsh net-destroy vnet_nated");
    save_screenshot;
}

sub post_fail_hook {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();

    #Restore default(NATed Network)
    virt_autotest::virtual_network_utils::restore_libvirt_default();
}

1;
