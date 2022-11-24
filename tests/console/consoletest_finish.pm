# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Cleanup and switch (back) to X11
# - from root-console execute 'loginctl --no-pager'
# - unmask packagekit.service
# - logout root (needed for KDE)
# - reset console
# - switch to normal user
# - logout user
# - reset console
# - if not in textmode, then ensure that desktop is unlocked
# Maintainer: QE Core <qe-core@suse.de>

use base "opensusebasetest";
use testapi;
use Utils::Architectures;
use utils;
use strict;
use warnings;
use x11utils 'ensure_unlocked_desktop';
use Utils::Logging 'export_logs';

sub run {
    my $self = shift;

    my $console = select_console 'root-console';
    # cleanup
    enter_cmd "loginctl --no-pager";
    wait_still_screen(2);
    save_screenshot();

    systemctl 'unmask packagekit.service';
    # On s390x sometimes the vnc will still be there and the next select_console
    # will create another vnc. This will make the OpenQA have 2 vnc sessions at
    # the same time. We'd cleanup the previous one and setup the new one.
    assert_script_run 'pkill Xvnc ||:' if !check_var('DESKTOP', 'textmode') && is_s390x;
    # logout root (and later user) so they don't block logout
    # in KDE
    enter_cmd "exit";
    $console->reset;

    $console = select_console 'user-console';
    enter_cmd "exit";    # logout
    $console->reset;
    wait_still_screen(2);

    save_screenshot();

    if (!check_var("DESKTOP", "textmode")) {
        select_console('x11', await_console => 0);
        ensure_unlocked_desktop;

        # system_prepare stops packagekitd while the applet is fetching updates.
        # This causes an (expected) error notification, which needs to be closed.
        if (check_screen('packagekit-stopped-notification-close')) {
            click_lastmatch;
        }
    }
}

sub post_fail_hook {
    my $self = shift;

    export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;

