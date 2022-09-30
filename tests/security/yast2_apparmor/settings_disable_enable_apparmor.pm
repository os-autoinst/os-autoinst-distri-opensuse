# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# yast2 apparmor" can disable/enable apparmor service
# Maintainer: QE Security <none@suse.de>
# Tags: poo#67021, tc#1741266

use base 'apparmortest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    # Yast2 AppArmor set up
    $self->yast2_apparmor_setup();

    # Check apparmor service is enabled
    $self->yast2_apparmor_is_enabled();

    # Disable apparmor service and check
    send_key "alt-e";
    assert_screen("AppArmor-Settings-Disable-Apparmor");
    wait_screen_change { send_key "alt-q" };
    type_string("\n");
    send_key "ctrl-c";
    enter_cmd("systemctl status apparmor | tee ");
    assert_screen("AppArmor_Inactive");

    # Enable apparmor service and check
    enter_cmd("yast2 apparmor &");
    assert_screen("AppArmor-Configuration-Settings", timeout => 180);
    assert_and_click("AppArmor-Launch", timeout => 60);
    assert_screen("AppArmor-Settings-Disable-Apparmor");
    send_key "alt-e";
    assert_screen("AppArmor-Settings-Enable-Apparmor");
    wait_screen_change { send_key "alt-q" };
    # Handle exception: the cursor disappears for no reason sometimes
    mouse_click("left");
    type_string("\n");
    send_key "ctrl-c";
    clear_console;
    assert_screen("root-console-x11");
    enter_cmd("systemctl status apparmor | tee ");
    assert_screen("AppArmor_Active");

    # Yast2 AppArmor clean up
    $self->yast2_apparmor_cleanup();
}

1;
