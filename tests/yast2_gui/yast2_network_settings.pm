# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_network_settings.pm checks Global options, Overview, Hostname/DNS, Routing
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "y2x11test";
use strict;
use testapi;

sub run {
    my $self   = shift;
    my $module = "lan";

    $self->launch_yast2_module_x11($module);
    assert_screen "yast2-$module-ui", 60;

    #	Global Options
    send_key 'alt-g';
    assert_screen 'yast2-network-settings_global-options';
    assert_screen 'yast2-network-settings_global-options_wicked-service';
    #	set dhcp client Identifier
    send_key 'alt-i';
    if (check_var('DISTRI', 'sle')) {
        type_string 'sle-host';
    }
    elsif (check_var('DISTRI', 'opensuse')) {
        type_string 'opensuse-host';
    }

    #	Overview, add a bridge
    send_key 'alt-v';
    assert_screen 'yast2-network-settings_overview';
    send_key 'alt-a';
    assert_and_click 'yast2-network-settings_overview_hardware-dialog_device-type';
    assert_and_click 'yast2-network-settings_overview_hardware-dialog_device-type_bridge';
    send_key 'alt-n';
    assert_screen 'yast2-network-settings_overview_network-card-setup';
    send_key 'alt-y';
    assert_screen 'yast2-network-settings_overview_network-card-setup_dynamic-add';
    send_key 'alt-n';

    #	Hostname/DNS, set hostname via dhcp, yes for br0
    send_key 'alt-s';
    assert_screen 'yast2-network-settings_hostname-dns';
    assert_and_click 'yast2-network-settings_hostname-dns_set-via-dhcp';
    assert_and_click 'yast2-network-settings_hostname-dns_br0';

    #	Routing, enable Forwarding
    send_key 'alt-u';
    assert_screen 'yast2-network-settings_routing';
    assert_and_click 'yast2-network-settings_routing_ipv4';
    assert_and_click 'yast2-network-settings_routing_ipv6';

    #	Save network setting and it can take long time, exit
    send_key "alt-o";
    wait_still_screen(60);
}

1;
# vim: set sw=4 et:
