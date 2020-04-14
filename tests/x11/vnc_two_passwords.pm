# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check VNC Secondary viewonly password
# - Stop vncmanager
# - Create custom passwords (one for readonly, other for # read/write)
# - Starts a vncserver with the custom password file
# - Starts a xterm
# - For each password (read only/read write)
#   - Starts xev to monitor events
#   - Launch vncview with supplied password
#   - Send some vnc events to xev
# - Check if events were recorded by xev
# - Close all opened windows
# Maintainer: mkravec <mkravec@suse.com>
# Tags: poo#11794

use base "x11test";
use strict;
use warnings;
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
    x11_start_program 'xterm';
    send_key 'super-left';
    type_string "vncviewer $display -SecurityTypes=VncAuth ; echo vncviewer-finished >/dev/$serialdev \n", timeout => 60;
    assert_screen 'vnc_password_dialog';
    type_string "$password\n";
    assert_screen 'vncviewer-xev';
    send_key 'super-left';
    wait_still_screen 2;

    # Send some vnc events to xev
    type_string 'events';
    mouse_set(80, 120);
    mouse_set(85, 125);
    mouse_click;

    send_key 'alt-f4';
    wait_serial 'vncviewer-finished';
    type_string "exit \n";
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
        # trap is needed because ctrl-c would kill the whole process group (cmd ; cmd)
        # eg.
        #     xev -display $display -root | tee /tmp/xev_log ; echo xev-finished >/dev/$serialdev
        # will not work
        # Parentheses are needed to not populate trap to following commands
        type_string "(trap 'echo xev-finished >/dev/$serialdev' SIGINT; xev -display $display -root | tee /tmp/xev_log) \n";

        # Repeat with RO/RW password
        generate_vnc_events $opt->{pw};

        # Close xev
        send_key 'ctrl-c';
        wait_serial 'xev-finished';

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
