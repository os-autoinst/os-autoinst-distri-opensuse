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

my @options = ({pw => "full_access_pw", change => 1}, {pw => "view_only_pw", change => 0});

sub type_and_wait {
    type_string shift;
    wait_screen_change {
        type_string "\n";
    };
}

sub start_vnc_server {
    # Disable remote administration from previous tests
    script_run "systemctl stop vncmanager";

    # Create password file
    type_string "tput civis\n";
    type_and_wait "vncpasswd /tmp/file.passwd";
    type_and_wait $options[0]->{pw};
    type_and_wait $options[0]->{pw};
    type_and_wait "y";
    type_and_wait $options[1]->{pw};
    type_and_wait $options[1]->{pw};
    type_string "tput cnorm\n";

    # Start server
    type_string "Xvnc :1 -SecurityTypes=VncAuth -PasswordFile=/tmp/file.passwd\n";
}

# poo#11794
sub run() {
    select_console "root-console";
    start_vnc_server;

    # Start xev event watcher
    select_console "x11";
    x11_start_program "xterm";
    send_key "super-right";
    type_string "DISPLAY=:1 xev\n";

    # Start vncviewer (rw & ro mode) and check if changes are processed by xev
    foreach my $opt (@options) {
        x11_start_program("vncviewer :1 -SecurityTypes=VncAuth");
        assert_screen "vnc_password_dialog";
        type_string "$opt->{pw}\n";
        send_key "super-left";
        mouse_set(80, 120);

        wait_still_screen;
        my $c1 = wait_screen_change { type_string "string"; };
        my $c2 = wait_screen_change { mouse_click; };
        if ($c1 != $c2 || $c1 != $opt->{change}) {
            die "Expected: $opt->{change}, received: $c1, $c2 for $opt->{pw}";
        }
        send_key "alt-f4";
    }

    # Cleanup
    send_key "alt-f4";
    select_console "root-console";
    send_key "ctrl-c";
    select_console "x11";
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
