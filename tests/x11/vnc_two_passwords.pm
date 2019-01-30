# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check VNC Secondary viewonly password
# Maintainer: mkravec <mkravec@suse.com>
# Tags: poo#11794

use base "x11test";
use strict;
use testapi;
use x11utils 'ensure_unlocked_desktop';

# Any free display
my $display = ':37';

# Passwords for VNC access
my @options = ({pw => "readonly_pw", change => 0}, {pw => "readwrite_pw", change => 1});

sub type_and_wait {
    type_string shift;
    wait_screen_change {
        type_string "\n";
    };
}

sub start_vnc_server {
    select_console "root-console";
    # Disable remote administration from previous tests
    script_run 'systemctl stop vncmanager';

    # Create password file
    type_string "tput civis\n";
    type_and_wait "vncpasswd /tmp/file.passwd";

    # Set read write password
    type_and_wait $options[1]->{pw};
    type_and_wait $options[1]->{pw};
    type_and_wait "y";

    # Set read only password
    type_and_wait $options[0]->{pw};
    type_and_wait $options[0]->{pw};
    type_string "tput cnorm\n";

    # Start server
    type_string "Xvnc $display -SecurityTypes=VncAuth -PasswordFile=/tmp/file.passwd\n";
    wait_still_screen 2;
    select_console 'x11';
}

sub generate_vnc_events {
    my $password = shift;

    # Login into vnc display in RO/RW mode
    x11_start_program("vncviewer $display -SecurityTypes=VncAuth", target_match => 'vnc_password_dialog', match_timeout => 60);
    type_string "$password\n";
    assert_screen 'vncviewer-xev';
    send_key "super-left";
    wait_still_screen 2;

    # Send some vnc events to xev
    type_string "events";
    mouse_set(80, 120);
    mouse_set(85, 125);
    mouse_click;

    send_key 'alt-f4';
}

sub run {
    record_info 'Setup VNC';
    start_vnc_server;

    # open xterm for xev
    x11_start_program('xterm');
    send_key "super-right";

    # Start vncviewer (rw & ro mode) and check if changes are processed by xev
    foreach my $opt (@options) {
        record_info 'Try ' . ($opt->{change} ? 'RW' : 'RO') . ' mode';

        # Start event watcher
        type_string "xev -display $display -root | tee /tmp/xev_log\n";

        # Repeat with RO/RW password
        generate_vnc_events $opt->{pw};

        # Close xev
        send_key 'ctrl-c';

        # Check if xev recorded events or not - RO/RW mode
        if ($opt->{change}) {
            assert_script_run '[ -s /tmp/xev_log ]';
        }
        else {
            assert_script_run 'wc -l /tmp/xev_log | grep "^0 "';
        }
        assert_script_run 'rm /tmp/xev_log';
    }

    # Cleanup
    send_key "alt-f4";
    select_console 'root-console', await_console => 0;
    send_key "ctrl-c";
    select_console "x11";
}

sub post_fail_hook {
    # xev seems to hang, send control-c to ensure that we can actually type
    send_key "ctrl-c";
    upload_logs('/tmp/xev_log', failok => 1);
}

1;
