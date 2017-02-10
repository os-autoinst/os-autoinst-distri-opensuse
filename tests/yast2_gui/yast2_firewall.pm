# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Extend YaST2 Firewall UI test
# Make sure yast2 firewall can opened properly. Configuratioins can be changed and written correctly.
# Maintainer: Max Lin <mlin@suse.com>

use base "y2x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;

    $self->launch_yast2_module_x11('firewall');

    assert_screen "yast2-firewall-ui", 30;

    # 	enter page interfaces and change zone for network interface
    assert_and_click("yast2_firewall_config_list");
    assert_screen "yast2_firewall_interfaces";
    assert_and_click("yast2_firewall_interface_zone_change");
    wait_still_screen(2);
    assert_and_click("yast2_firewall_interface_no-zone_assigned");
    wait_screen_change {
        send_key "down";
        send_key "ret"
    };
    send_key "alt-o";

    # 	enter page Allowed Services and make  some changes
    assert_and_click("yast2_firewall_allowed-services");
    assert_and_click("yast2_firewall_service-to-allow");
    assert_and_click("yast2_firewall_service_http");
    send_key "alt-a";
    assert_screen "yast2_firewall_service_http_addded";

    #	enter page Broadcast and disable logging broadcast packets
    assert_and_click("yast2_firewall_broadcast");
    send_key "alt-l";
    send_key "alt-o";
    assert_screen "yast2_firewall_broadcast_no-logging";

    # 	enter page Logging Level and disable logging
    assert_and_click("yast2_firewall_logging-level");
    assert_and_click("yast2_firewall_do-not-log-any_accepted");
    assert_and_click("yast2_firewall_do-not-log-any_not-accepted");

    #	enter page Custom Rules and check ui
    assert_and_click("yast2_firewall_custom-rules");
    send_key "alt-a";
    assert_screen "yast2_firewall_add-new-allowing-rules";
    send_key "alt-c";
    wait_still_screen(2);

    #	Next to finish and exit
    send_key "alt-n";
    assert_screen "yast2_firewall_summary", 30;
    send_key "alt-f";
}

1;
# vim: set sw=4 et:
