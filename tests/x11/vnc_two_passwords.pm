# SUSE's openQA tests
#
# Copyright © 2016-2020 SUSE LLC
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
#             Felix Niederwanger <felix.niederwanger@suse.de>
# Tags: poo#11794

use base "x11test";
use strict;
use warnings;
use testapi;
use x11utils 'ensure_unlocked_desktop';
use version_utils 'is_sle';
use utils;

# Any free display
my $display = ':37';

# Passwords for VNC access
my @options = ({pw => "readonly_pw", change => 0}, {pw => "readwrite_pw", change => 1});
# A wrong password to check if the access is denied
my $wrong_password = "password123";

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

    # Also set the password via `vncpasswd -f` for vncserver and to test for https://bugzilla.opensuse.org/show_bug.cgi?id=1171519
    assert_script_run('umask 0077');
    script_run('mkdir $HOME/.vnc');
    assert_script_run('chmod go-rwx "$HOME/.vnc"');
    if (script_run("echo \"$options[1]->{pw}\" | vncpasswd -f > \$HOME/.vnc/passwd; echo \"$options[0]->{pw}\" | vncpasswd -f >> \$HOME/.vnc/passwd") != 0) {
        record_soft_failure('vncpasswd crashes - bsc#1171519');
        assert_script_run('cp /tmp/file.passwd $HOME/.vnc/passwd');
    }

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
    wait_serial('vncviewer-finished') || die 'vncviewer not finished';
    type_string "exit \n";
}

sub run {
    record_info 'Setup VNC';
    select_console('root-console');
    zypper_call('in tigervnc xorg-x11-Xvnc xev');
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
        wait_serial('xev-finished') || die 'xev not finished';

        # Check if xev recorded events or not - RO/RW mode
        if ($opt->{change}) {
            assert_script_run '[ -s /tmp/xev_log ]';
        }
        else {
            assert_script_run 'wc -l /tmp/xev_log | grep "^0 "';
        }
        assert_script_run 'rm /tmp/xev_log';
    }

    # Stop Xvnc
    send_key "alt-f4";
    select_console 'root-console', await_console => 0;
    send_key "ctrl-c";
    wait_still_screen 2;

    # Start vncserver and check if it is running
    assert_script_run("vncserver $display -geometry 1024x768 -depth 16", fail_message => "vncserver is not starting");
    script_run("vncserver -list > /var/tmp/vncserver-list");
    assert_script_run("grep '$display' /var/tmp/vncserver-list", fail_message => "vncserver is not running");
    # The needles for the tigervnc test are gnome specific
    if (check_var('DESKTOP', 'gnome')) {
        # Switch to desktop and run vncviewer
        select_console('x11');
        ensure_unlocked_desktop;
        x11_start_program('vncviewer');
        type_string("$display");
        send_key("ret");
        # We first test for a unsucessfull login
        assert_screen('tigervnc-desktop-login');
        type_string("$wrong_password");
        send_key("ret");
        assert_screen('tigervnc-login-fail');
        send_key("ret");
        # Test for a sucessfull login. Note: vncviewer remembers the last address, don't type it again
        x11_start_program('vncviewer');
        send_key("ret");
        assert_screen('tigervnc-desktop-login');
        type_string("$options[1]->{pw}");
        send_key("ret");
        assert_screen('tigervnc-desktop-loggedin');
        save_screenshot();
        send_key("alt-f4");
        x11_start_program('vncviewer');
        send_key("ret");
        assert_screen('tigervnc-desktop-login');
        type_string("$options[0]->{pw}");
        send_key("ret");
        assert_screen('tigervnc-desktop-loggedin');
        save_screenshot();
        send_key("alt-f4");
    } else {
        record_info("skipping graphical vnc tests (non-gnome desktop)");
    }
    # Terminate server
    select_console('root-console');
    assert_script_run("vncserver -kill $display");
    # Done
    select_console('x11');
}

sub post_fail_hook {
    # xev seems to hang, send control-c to ensure that we can actually type
    send_key "ctrl-c";
    upload_logs('/tmp/xev_log', failok => 1);
}

1;
