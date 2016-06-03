# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

sub pre_run_hook() {
    # Turn off screensaver
    x11_start_program("kcmshell5 screenlocker");
    send_key("alt-l");
    send_key("alt-o");
}

# Update with Plasma applet for software updates using PackageKit
sub run() {
    my @updates_installed_tags = qw/updates_none updates_available/;

    if (check_screen("updates_available-tray")) {
        assert_and_click("updates_available-tray");

        # First update package manager, then packages
        for (1 .. 2) {
            assert_and_click("updates_click-install");

            # Wait until installation is done
            assert_screen \@updates_installed_tags, 3600;
            if (match_has_tag("updates_none")) {
                last;
            }
        }
        # Close tray updater
        send_key("alt-f4");
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
