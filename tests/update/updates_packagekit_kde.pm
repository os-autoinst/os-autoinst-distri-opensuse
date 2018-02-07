# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Packagekit updates using kde applet
# Maintainer: mkravec <mkravec@suse.com>

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

# Update with Plasma applet for software updates using PackageKit
sub run {
    my ($self) = @_;
    select_console 'x11', await_console => 0;
    turn_off_kde_screensaver;

    my @updates_installed_tags = qw(updates_none updates_available);
    assert_screen [qw(updates_available-tray tray-without-updates-available)];
    if (match_has_tag 'updates_available-tray') {
        assert_and_click("updates_available-tray");

        # First update package manager, then packages, then bsc#992773 (2x)
        while (1) {
            assert_and_click('updates_click-install');

            # Wait until installation is done
            assert_screen \@updates_installed_tags, 3600;
            # Make sure we saw the right string and the same screen or a
            # different one
            wait_still_screen;
            if (match_has_tag('updates_none')) {
                if (check_screen 'updates_none') {
                    last;
                }
                else {
                    record_soft_failure 'boo#992773';
                }
            }
            elsif (match_has_tag('updates_available')) {
                # look again
                if (check_screen 'updates_none', 0) {
                    record_soft_failure 'boo#1041112';
                    last;
                }
            }
        }
        # Close tray updater
        send_key("alt-f4");
    }

    if (kernel_updated) {
        type_string "reboot\n";
        $self->wait_boot;
    }
    else {
        select_console "x11";
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
