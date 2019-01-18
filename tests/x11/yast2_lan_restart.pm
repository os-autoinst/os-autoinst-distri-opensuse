# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: YaST logic on Network Restart while no config changes were made
# Maintainer: Zaoliang Luo <zluo@suse.com>
# Tags: fate#318787 poo#11450

use base 'y2logsstep';

use strict;
use warnings;
use testapi;
use y2lan_restart_common;
use y2_common 'is_network_manager_default';

sub check_network_settings_tabs {
    send_key 'alt-g';    # Global options tab
    assert_screen 'yast2_lan_global_options_tab';
    send_key 'alt-s';    # Hostname/DNS tab
    assert_screen 'yast2_lan_hostname_tab';
    send_key 'alt-u';    # Routing tab
    assert_screen 'yast2_lan_routing_tab';
}

sub check_network_card_setup_tabs {
    wait_screen_change { send_key 'home' };
    send_key_until_needlematch 'yast2_lan_select_eth_card', 'down';
    send_key 'alt-i';
    assert_screen 'yast2_lan_network_card_setup';
    send_key 'alt-w';
    assert_screen 'yast2_lan_hardware_tab';
    send_key 'alt-g';
    assert_screen 'yast2_lan_general_tab';
    send_key 'alt-n';
}

sub check_default_gateway {
    send_key 'alt-u';    # Routing tab
    assert_screen 'yast2_lan_routing_tab';
    send_key 'alt-f';    # select Default IPv4 Gateway
    type_string '10.0.2.2';
    save_screenshot;
    send_key 'alt-g';    # Global options tab
    assert_screen 'yast2_lan_global_options_tab';
    send_key 'alt-u';    # Routing tab
    assert_screen 'yast2_lan_routing_tab';
    send_key 'alt-f';
    send_key 'backspace';    # Delete selected IP
}

sub change_hw_device_name {
    my $dev_name = shift;

    send_key 'alt-i';        # Edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    send_key 'alt-w';        # Hardware tab
    assert_screen 'yast2_lan_hardware_tab';
    send_key 'alt-e';        # Change device name
    assert_screen 'yast2_lan_device_name';
    send_key 'tab' for (1 .. 2);
    type_string $dev_name;
    wait_screen_change { send_key 'alt-m' };    # Udev rule based on MAC
    save_screenshot;
    send_key $cmd{ok};
    send_key $cmd{next};
}

sub run {
    initialize_y2lan;
    verify_network_configuration;               # check simple access to Overview tab
    verify_network_configuration(\&check_network_settings_tabs);
    unless (is_network_manager_default) {
        check_etc_hosts_update() if (check_var('BACKEND', 'qemu'));
        verify_network_configuration(\&check_network_card_setup_tabs);
        verify_network_configuration(\&check_default_gateway);
        verify_network_configuration(\&change_hw_device_name, 'dyn0', 'restart');
    }
    type_string "killall xterm\n";
}

sub post_fail_hook {
    my ($self) = @_;

    assert_script_run 'journalctl -b > /tmp/journal', 90;
    upload_logs '/tmp/journal';
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {always_rollback => 1};
}

1;
