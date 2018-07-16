# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure system can reboot from plasma5 session
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    send_key "ctrl-alt-delete";    # reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'sddm_reboot_option_btn';
    if (check_screen([qw(sddm_reboot_option_btn sddm_reboot_btn)], 3)) {
        # sometimes not reliable, since if clicked the background
        # color of button should changed, thus check and click again
        if (match_has_tag('sddm_reboot_option_btn')) {
            assert_and_click 'sddm_reboot_option_btn';
        }
        # plasma < 5.8
        elsif (match_has_tag('sddm_reboot_btn')) {
            assert_and_click 'sddm_reboot_btn';
        }
    }
    # else: plasma 5.8 directly reboots after pressing the reboot button

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth', 15;
        type_password;
        send_key "ret";
    }
    $self->wait_boot;
    # Ensure the desktop runner is reactive again before going into other test
    # modules
    # https://progress.opensuse.org/issues/30805
    $self->check_desktop_runner;
}

sub test_flags {
    return {milestone => 1};
}

1;

