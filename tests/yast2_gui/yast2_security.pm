# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks that YaST2's Security module is behaving
#          correctly by changing some values and verifying that they
#          have been successfully set.
# - Launch yast2 security
# - Access Password Settings, change minimum password lenght to "8", change
# days before expiration warning to "30"
# - Launch yast2 security and check the values on Password Settings
# - Access Login Settings and change Delay after Incorrect login attempt to "5"
# - Launch yast2 security and check the values on Login Settings
# - Access Miscellaneous Settings, Change File Permissions to "secure"
# - Launch yast2 security again and check the values on Miscellaneous Settings
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    select_console "x11";

    # Password Settings
    $self->launch_yast2_module_x11("security", match_timeout => 120);
    assert_and_click "yast2_security-pwd-settings";
    send_key "alt-m";
    wait_still_screen 1;
    wait_screen_change { type_string "8" };
    send_key "alt-d";
    wait_still_screen 1;
    wait_screen_change { type_string "30" };
    wait_screen_change { send_key "alt-o" };

    # Check previously set values + Login Settings
    $self->launch_yast2_module_x11("security", match_timeout => 120);
    assert_and_click "yast2_security-pwd-settings";
    assert_screen "yast2_security-check-min-pwd-len-and-exp-days";
    assert_and_click "yast2_security-login-settings";
    send_key "alt-d";
    wait_still_screen 1;
    wait_screen_change { type_string "5" };
    wait_screen_change { send_key "alt-o" };

    # Check previously set values + Miscellaneous Settings
    $self->launch_yast2_module_x11("security", match_timeout => 120);
    assert_and_click "yast2_security-login-settings";
    assert_screen "yast2_security-login-attempts";
    # set file permissions to 'secure'
    assert_and_click "yast2_security-misc-settings";
    send_key "alt-f";
    wait_screen_change { send_key "down" };
    wait_screen_change { send_key "alt-o" };

    # Check previously set values
    $self->launch_yast2_module_x11("security", match_timeout => 120);
    assert_and_click "yast2_security-misc-settings";
    assert_screen "yast2_security-file-perms-secure";
    wait_screen_change { send_key "alt-o" };
}

1;
