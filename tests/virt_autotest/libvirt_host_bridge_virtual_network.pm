# SUSE's openQA tests
#
# Copyright 2019-2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: HOST bridge virtual network test:
#    - Create HOST bridge virtual network
#    - Confirm HOST bridge virtual network
#    - Destroy HOST bridge virtual network
# Maintainer: Leon Guo <xguo@suse.com>, qe-virt@suse.de

use base "virt_feature_test_base";
use virt_utils;
use virt_autotest::virtual_network_utils;
use virt_autotest::utils;
use testapi;
use utils;
use version_utils qw(is_sle);

our $virt_host_bridge = 'br0';
our $based_guest_dir = 'tmp';
sub run_test {
    my ($self) = @_;

    # SLES16 has done this in earlier setup
    unless (is_sle('16+')) {
        #Prepare VM HOST SERVER Network Interface Configuration
        #for libvirt virtual network testing
        virt_autotest::virtual_network_utils::prepare_network($virt_host_bridge, $based_guest_dir);
    }

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

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "HOST BRIDGE NETWORK for $guest";
        my $data = virt_autotest::virtual_network_utils::get_virtual_network_data($guest, net => "vnet_host_bridge");
        #Ensures the given guests is started and fixes some common network issues
        ensure_online $guest, $data->{skip_type} => 1;
        save_screenshot;

        my $mac = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        #Check guest loaded kernel module before attach interface to guest system
        check_guest_module("$guest", module => "acpiphp");
        assert_script_run("virsh attach-interface $guest network vnet_host_bridge --model $data->{model} --mac $mac --live $data->{affecter}", 60);

        test_network_interface($guest, mac => $mac, gateway => $data->{gateway}, net => $data->{net});

        assert_script_run("virsh detach-interface $guest bridge --mac $mac $data->{exclusive}");
        my $check = script_run("ssh root\@$guest ip l | grep " . $mac, 60);
        die "Failed to detach bridge interface for guest $guest." if ($check eq 0);
    }

    #Destroy HOST BRIDGE NETWORK
    assert_script_run("virsh net-destroy vnet_host_bridge");
    save_screenshot;

    #Restore Network setting after finished HOST BRIDGE NETWORK Test
    virt_autotest::virtual_network_utils::restore_network($virt_host_bridge, $based_guest_dir);
}

sub post_fail_hook {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();

    #Restore Network setting
    virt_autotest::virtual_network_utils::restore_network($virt_host_bridge, $based_guest_dir);
}

1;
