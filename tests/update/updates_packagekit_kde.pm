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
use utils;
use testapi;

# Check if running kernel is the last installed
sub kernel_updated {
    select_console "root-console";
    my $current = script_output "uname -r | cut -d'-' -f1,2";
    return script_run "rpm -q --last kernel-default | head -1 | grep $current";
}

sub turn_off_screensaver() {
    x11_start_program("kcmshell5 screenlocker");
    send_key("alt-l");
    send_key("alt-o");
}

# Update with Plasma applet for software updates using PackageKit
sub run() {
    turn_off_screensaver;

    my @updates_installed_tags = qw/updates_none updates_available/;
    if (check_screen("updates_available-tray")) {
        assert_and_click("updates_available-tray");

        # First update package manager, then packages, then bsc#992773 (2x)
        while (1) {
            assert_and_click("updates_click-install");

            # Wait until installation is done
            assert_screen \@updates_installed_tags, 3600;
            if (match_has_tag("updates_none")) {
                wait_still_screen;
                if (check_screen "updates_none") {
                    last;
                }
                else {
                    record_soft_failure 'bsc#992773';
                }
            }
        }
        # Close tray updater
        send_key("alt-f4");
    }

    if (kernel_updated) {
        type_string "reboot\n";
        wait_boot;
    }
    else {
        select_console "x11";
    }
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
