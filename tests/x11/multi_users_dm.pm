# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: Test if login manager is usable with many users
#   This test checks if many users make the login manager hard to use
#   i.e. if it takes more than one click to access the username text field
# Maintainer: Dominik Heidler <dheidler@suse.de>, Rodion Iafarov <riafarov@suse.com>
# Tags: poo#9694

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use x11utils qw(handle_login handle_logout handle_welcome_screen);
use main_common 'opensuse_welcome_applicable';

sub ensure_multi_user_target {
    type_string "systemctl isolate multi-user.target\n";
    wait_still_screen 5;
    send_key "ctrl-alt-f" . get_root_console_tty;
    wait_screen_change {
        send_key "ctrl-c";
    }
    reset_consoles;
    wait_still_screen 10;
    # isolating multi-user.target logs us out
    select_console 'root-console';
}

sub ensure_graphical_target {
    type_string "systemctl isolate graphical.target\n";
    reset_consoles;
}

sub run {
    my $self = shift;

    my $user               = 'user1';
    my $users_to_create    = 100;
    my $encrypted_password = crypt($password, "abcsalt");

    # disable autologin
    select_console 'root-console';
    assert_script_run "sed -i.bak '/^DISPLAYMANAGER_AUTOLOGIN=/s/=.*/=\"\"/' /etc/sysconfig/displaymanager";
    assert_script_run "~$username/data/create_users $users_to_create \"$encrypted_password\"";

    # login created user
    select_console 'x11';
    handle_logout;
    assert_screen 'multi_users_dm', 180;    # gnome loading takes long sometimes
    wait_still_screen;
    if (check_var('DESKTOP', 'gnome')) {
        wait_screen_change { assert_and_click('user_not_listed') };
    }
    elsif (check_var('DESKTOP', 'xfce')) {
        # select created user #01
        send_key_until_needlematch(['user-01-selected', 'user-freetext-input-selected'], 'down', 1, 3);
        if (match_has_tag 'user-freetext-input-selected') {
            type_string "$user\n";
        }
    }
    elsif (check_var('DESKTOP', 'kde')) {
        wait_screen_change { send_key 'shift-tab' };
        send_key 'ctrl-a';
        type_string "$user\n";
    }
    # Make sure screen changed before calling handle_login function (for slow workers)
    wait_still_screen;
    handle_login($user, 1);
    handle_welcome_screen(timeout => 120) if (opensuse_welcome_applicable);
    assert_screen 'generic-desktop', 60;
    # verify correct user is logged in
    x11_start_program('xterm');
    wait_still_screen;
    type_string "whoami|grep $user > /tmp/whoami.log\n";
    assert_script_sudo "grep $user /tmp/whoami.log";
    # logout user
    handle_logout;
    wait_still_screen;

    # restore previous config
    select_console 'root-console';
    script_run "mv /etc/sysconfig/displaymanager.bak /etc/sysconfig/displaymanager";
    assert_script_run "~$username/data/delete_users $users_to_create";
    script_run "clear";
    assert_script_run "rcxdm restart";
    select_console 'x11';
    # after restart of X11 give the desktop a bit more time to show up to
    # prevent the post_run_hook to fail being too impatient
    assert_screen 'generic-desktop', 600;
}

1;
