# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-network
# Summary: yast2_network_settings.pm checks Global options, Overview, Hostname/DNS, Routing
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use y2_module_basetest 'is_network_manager_default';
use version_utils 'is_sle';
use YaST::workarounds;

sub run {

    # keyboard shorcuts
    $cmd{global_options_tab} = 'alt-g';
    $cmd{dhcp_client_id} = 'alt-i';
    $cmd{overview_tab} = 'alt-v';
    $cmd{add_device} = 'alt-a';
    $cmd{dynamic_address} = 'alt-y';
    $cmd{hostname_dns_tab} = 'alt-s';
    $cmd{routing_tab} = 'alt-u';

    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11('lan', target_match => [qw(yast2-lan-ui yast2_still_susefirewall2 yast2-lan-warning-network-manager)], match_timeout => 120);
    if (match_has_tag 'yast2_still_susefirewall2') {
        send_key $cmd{install};
        wait_still_screen;
    }
    elsif (match_has_tag('yast2-lan-warning-network-manager') || is_network_manager_default) {
        assert_screen 'yast2-lan-warning-network-manager';    # assert twice due to sometimes screen matches just before pop-up appears
        send_key $cmd{ok};
        assert_screen 'yast2-lan-ui';
    }
    # Global options
    send_key $cmd{global_options_tab};
    assert_screen 'yast2-network-settings_global-options';
    if (is_network_manager_default) {
        assert_screen 'yast2-lan-network-manager-selected';
    }
    else {
        assert_screen 'yast2-network-settings_global-options_wicked-service';
        send_key $cmd{dhcp_client_id};
        type_string(get_var('DISTRI') . '-host') if get_var("DISTRI") =~ /(sle|opensuse)/;
    }
    # Overview tab
    # When controlled by NM we cannot edit anything in the UI and in latest version
    # it's not even possible to open the tab and warning will be shown, so skip this tab completely
    unless (is_network_manager_default) {
        send_key $cmd{overview_tab};
        assert_screen 'yast2-network-settings_overview';
        wait_still_screen 2;
        send_key $cmd{add_device};
        # Older than 15-SP2 versions require two steps to select device type: expand the list and then select the option.
        # On 15-SP2 it is a list of radio buttons, so only one step with selecting the radio is needed.
        if (is_sle('<15-SP2')) {
            assert_and_click 'yast2-network-settings_overview_hardware-dialog_device-type';
        }
        apply_workaround_poo124652('yast2-network-settings_overview_hardware-dialog_device-type_bridge');
        assert_and_click 'yast2-network-settings_overview_hardware-dialog_device-type_bridge';
        send_key $cmd{next};
        assert_screen 'yast2-network-settings_overview_network-card-setup';
        send_key $cmd{dynamic_address};
        assert_screen 'yast2-network-settings_overview_network-card-setup_dynamic-add';
        send_key $cmd{next};
    }
    # Hostname/DNS tab
    send_key $cmd{hostname_dns_tab};
    assert_screen 'yast2-network-settings_hostname-dns';
    unless (is_network_manager_default) {
        assert_screen([qw(yast2-network-settings_hostname-dns_set-via-dhcp dns_set-via-dhcp_no)], 90);
        if (match_has_tag('dns_set-via-dhcp_no')) {
            assert_and_click 'dns_set-via-dhcp_no';
        }
        else {
            assert_and_click 'yast2-network-settings_hostname-dns_set-via-dhcp';
        }
        assert_and_click 'yast2-network-settings_hostname-dns_br0';
    }
    # Routing tab
    send_key $cmd{routing_tab};
    assert_screen 'yast2-network-settings_routing';
    unless (is_network_manager_default) {
        assert_and_click 'yast2-network-settings_routing_ipv4';
        assert_and_click 'yast2-network-settings_routing_ipv6';
    }
    send_key $cmd{ok};
}

sub post_run_hook {
    assert_screen('generic-desktop', 300);
}

1;
