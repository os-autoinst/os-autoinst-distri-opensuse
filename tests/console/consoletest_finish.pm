# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Cleanup and switch (back) to X11
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "opensusebasetest";
use testapi;
use utils;
use strict;

sub run() {
    my $self = shift;

    my $console = select_console 'root-console';
    # cleanup
    type_string "loginctl --no-pager\n";
    wait_still_screen(2);
    save_screenshot();

    script_run "systemctl unmask packagekit.service";

    # logout root (and later user) so they don't block logout
    # in KDE
    type_string "exit\n";
    $console->reset;

    $console = select_console 'user-console';

    send_key "ctrl-c";
    wait_still_screen(1);
    type_string "exit\n";    # logout
    $console->reset;
    wait_still_screen(2);

    save_screenshot();

    if (!check_var("DESKTOP", "textmode")) {
        select_console('x11');
        ensure_unlocked_desktop;
    }
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;

# vim: set sw=4 et:
