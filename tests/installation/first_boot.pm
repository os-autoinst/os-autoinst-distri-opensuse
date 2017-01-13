# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
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

sub handle_login {
    mouse_hide();
    wait_still_screen;
    if (get_var('DM_NEEDS_USERNAME')) {
        type_string "$username\n";
    }
    if (check_var('DESKTOP', 'gnome') || (check_var('DESKTOP', 'lxde') && check_var('VERSION', '42.1'))) {
        # In GNOME/gdm, we do not have to enter a username, but we have to select it
        send_key 'ret';
    }
    assert_screen "displaymanager-password-prompt";
    type_password;
    send_key "ret";
}

sub handle_first_desktop {
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

sub run() {
    my $self = shift;

    if (check_var('DESKTOP', 'textmode') || get_var('BOOT_TO_SNAPSHOT')) {
        if (!check_var('ARCH', 's390x')) {
            assert_screen 'linux-login', 200;
        }
        return;
    }

    if (get_var("NOAUTOLOGIN") || get_var("IMPORT_USER_DATA")) {
        assert_screen [qw(displaymanager emergency-shell emergency-mode)], 200;
        if (match_has_tag('emergency-shell')) {
            # get emergency shell logs for bug, scp doesn't work
            script_run "cat /run/initramfs/rdsosreport.txt > /dev/$serialdev";
        }
        elsif (match_has_tag('emergency-mode')) {
            type_password;
            send_key 'ret';
        }
    }
    else {
        handle_first_desktop;
        # hide mouse for clean logout needles
        mouse_hide();
        # logout to test login on openSUSE https://progress.opensuse.org/issues/13306
        if (check_var('DESKTOP', 'gnome') || check_var('DESKTOP', 'lxde')) {
            my $command = check_var('DESKTOP', 'gnome') ? 'gnome-session-quit' : 'lxsession-logout';
            x11_start_program("$command");    # opens logout dialog
            assert_screen 'logoutdialog' unless check_var('DESKTOP', 'gnome');
        }
        else {
            my $key = check_var('DESKTOP', 'xfce') ? 'alt-f4' : 'ctrl-alt-delete';
            send_key_until_needlematch 'logoutdialog', "$key";    # opens logout dialog
        }
        assert_and_click 'logout-button';                         # press logout
    }
    handle_login;
    handle_first_desktop;
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook() {
    my $self = shift;

    diag 'Save memory dump to debug bootup problems, e.g. for bsc#1005313';
    save_memory_dump;

    # Reveal what is behind Plymouth splash screen
    assert_screen_change {
        send_key 'esc';
    };
    $self->export_logs();
}

1;

# vim: set sw=4 et:
