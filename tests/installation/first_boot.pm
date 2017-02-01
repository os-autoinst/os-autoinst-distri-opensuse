# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Special handling to get to the desktop the first time after
#          the installation has been completed (either find the desktop after
#          auto-login or handle the login screen to reach the desktop)
# Maintainer: Max Lin <mlin@suse.com>

use strict;
use base "y2logsstep";
use testapi;
use utils qw(handle_login handle_emergency);

sub run() {
    my $boot_timeout = 200;
    if (check_var('DESKTOP', 'textmode') || get_var('BOOT_TO_SNAPSHOT')) {
        assert_screen('linux-login', $boot_timeout) unless check_var('ARCH', 's390x');
        return;
    }

    if (get_var("NOAUTOLOGIN") || get_var("IMPORT_USER_DATA")) {
        assert_screen [qw(displaymanager emergency-shell emergency-mode)], $boot_timeout;
        handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));
        handle_login;
    }

    my @tags = qw(generic-desktop);
    if (check_var('DESKTOP', 'kde') && get_var('VERSION', '') =~ /^1[23]/) {
        push(@tags, 'kde-greeter');
    }
    # GNOME and KDE get into screenlock after 5 minutes without activities.
    # using multiple check intervals here then we can get the wrong desktop
    # screenshot at least in case desktop screenshot changed, otherwise we get
    # the screenlock screenshot.
    my $timeout        = 600;
    my $check_interval = 30;
    while ($timeout > $check_interval) {
        my $ret = check_screen \@tags, $check_interval;
        last if $ret;
        $timeout -= $check_interval;
    }
    # the last check after previous intervals must be fatal
    assert_screen \@tags, $check_interval;
    if (match_has_tag('kde-greeter')) {
        send_key "esc";
        assert_screen 'generic-desktop';
    }
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook() {
    my $self = shift;

    # Reveal what is behind Plymouth splash screen
    wait_screen_change {
        send_key 'esc';
    };
    # if we found a shell, we do not need the memory dump
    unless (match_has_tag('emergency-shell') or match_has_tag('emergency-mode')) {
        diag 'Save memory dump to debug bootup problems, e.g. for bsc#1005313';
        save_memory_dump;
    }

    # try to save logs as a last resort
    $self->export_logs();
}

1;
# vim: set sw=4 et:
