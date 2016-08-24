# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# This test checks if many users make the login manager hard to use
# i.e. if it takes more than one click to access the username text field

use base "x11test";
use strict;
use testapi;

sub ensure_multi_user_target {
    type_string "systemctl isolate multi-user.target\n";
    reset_consoles;
    wait_still_screen 10;
    # isolating multi-user.target logs us out
    select_console 'root-console';
    if (check_var('DESKTOP', 'gnome')) {
        # if all is well, there is no gdm-x-session process remaining
        my $gdmpid = script_output "pidof /usr/lib/gdm/gdm-x-session || true";
        if ($gdmpid ne "") {
            # gdm did not bring down its children
            record_soft_failure 'boo#976764 - GDM does not restart';
            script_run "killall gdm-x-session";
            # display jumps to gdm's vt, move back to root-console
            select_console 'root-console';
        }
    }
}

sub ensure_graphical_target {
    type_string "systemctl isolate graphical.target\n";
    reset_consoles;
}

sub restart_x11 {
    ensure_multi_user_target;
    ensure_graphical_target;
}

sub run() {
    my $self = shift;

    my $users_to_create = 100;
    my $encrypted_password = crypt($password, "abcsalt");

    # login
    select_console 'root-console';

    # disable autologin
    script_run "sed -i.bak '/^DISPLAYMANAGER_AUTOLOGIN=/s/=.*/=\"\"/' /etc/sysconfig/displaymanager";
    assert_script_run "~$username/data/create_users $users_to_create \"$encrypted_password\"";
    restart_x11;

    assert_screen "multi_users_dm";

    # restore previous config
    select_console 'root-console';
    script_run "mv /etc/sysconfig/displaymanager.bak /etc/sysconfig/displaymanager";
    assert_script_run "~$username/data/delete_users $users_to_create";
    script_run "clear";
    restart_x11;
}

1;
# vim: set sw=4 et:
