# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: xorg-x11-Xvnc ncurses-utils tigervnc xev
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
use version_utils qw(is_sle is_tumbleweed package_version_cmp);
use utils;
use Utils::Architectures qw(is_aarch64 is_ppc64le);
use serial_terminal qw(select_serial_terminal set_serial_prompt);

# set global timeout, increased for aarch64
my $timeout = (is_aarch64 && is_sle) ? 120 : 30;

# Any free display
my $display = ':37';

# Passwords for VNC access
my @options = ({pw => "ropasswd", change => 0}, {pw => "rwpasswd", change => 1});
# A wrong password to check if the access is denied
my $wrong_password = "badpass";

my $test_xauth;
my $tigervnc_vers;
my $curr_vers;

sub setup_vnc_server {
    # Disable remote administration from previous tests
    script_run 'systemctl stop vncmanager';
    assert_script_run('mkdir /etc/tigervnc') if $curr_vers < 0;

    # Config done following this guide:
    # https://github.com/TigerVNC/tigervnc/blob/master/unix/vncserver/HOWTO.md
    #   1. Add a user mapping
    assert_script_run("echo -e \"$display=testuser\\n\" >> /etc/tigervnc/vncserver.users");
    #   2. Configure Xvnc options
    assert_script_run('echo -e "geometry=1024x768\ndepth=16" >> /etc/tigervnc/vncserver-config-defaults');

    enter_cmd 'su - testuser';
    sleep 2;
    set_serial_prompt '> ';

    if ($curr_vers < 0) {
        assert_script_run('umask 0077');
        assert_script_run('mkdir -Z $HOME/.vnc');
        assert_script_run('chmod go-rwx "$HOME/.vnc"');
        script_output(qq(expect -c 'spawn vncpasswd /tmp/file.passwd; expect "Password:"; send $options[1]->{pw}\\r; expect "Verify:"; send $options[1]->{pw}\\r; expect "view-only"; send y\\r; expect "Password:"; send $options[0]->{pw}\\r; expect "Verify:"; send $options[0]->{pw}\\r ; interact'));
        if (script_run("echo \"$options[1]->{pw}\" | vncpasswd -f > \$HOME/.vnc/passwd; echo \"$options[0]->{pw}\" | vncpasswd -f >> \$HOME/.vnc/passwd") != 0) {
            record_soft_failure('vncpasswd crashes - bsc#1171519');
            assert_script_run('cp /tmp/file.passwd $HOME/.vnc/passwd');
        }
        wait_still_screen 2;
        record_info("TigerVNC version", "TigerVNC version $tigervnc_vers is lesser than 1.12.0");
        assert_script_run("vncserver $display -geometry 1024x768 -depth 16", fail_message => "vncserver is not starting");
        script_run("vncserver -list > /var/tmp/vncserver-list");
        assert_script_run("grep '$display' /var/tmp/vncserver-list", fail_message => "vncserver is not running");
        set_serial_prompt '# ';
        enter_cmd 'exit';
        sleep 2;
    }
    else {
        script_output(qq(expect -c 'spawn vncpasswd; expect "Password:"; send $options[1]->{pw}\\r; expect "Verify:"; send $options[1]->{pw}\\r; expect "view-only"; send y\\r; expect "Password:"; send $options[0]->{pw}\\r; expect "Verify:"; send $options[0]->{pw}\\r ; interact'));
        script_output("echo \"$options[1]->{pw}\" | vncpasswd -f");    # bsc#1171519
        script_output(qq(expect -c 'spawn vncpasswd -f /home/testuser/.config/tigervnc/passwd; expect "Password:"; send $options[1]->{pw}\\r; expect "Verify:"; send $options[1]->{pw}\\r; expect "view-only"; send y\\r; expect "Password:"; send $options[0]->{pw}\\r; expect "Verify:"; send $options[0]->{pw}\\r ; interact'));
        record_info("TigerVNC version", "TigerVNC version $tigervnc_vers is greater than of equal to 1.12.0");
        set_serial_prompt '# ';
        enter_cmd 'exit';
        sleep 2;
        assert_script_run("systemctl start vncserver\@$display", fail_message => "New version of vncserver is not starting");
        assert_script_run("systemctl status vncserver\@$display", fail_message => "New version of vncserver is not running");
        sleep 3;
    }
    # get xauth of testuser so bernhard can access testuser display :37 with xev
    $test_xauth = script_output("sudo -u testuser xauth list|awk '{print\$3}'|head -n1");
    select_console 'x11';
}

sub prepare_vnc {
    # maximize vnc window and press esc to close the gnome activity
    wait_still_screen 2;
    send_key 'super-up';
    wait_still_screen 2;
    send_key_until_needlematch 'tigervnc-desktop-loggedin', 'esc', 5, 5;
}

sub generate_vnc_events {
    my $password = shift;

    # Login into vnc display in RO/RW mode
    x11_start_program 'xterm';
    send_key 'super-left';
    enter_cmd "vncviewer $display -SecurityTypes=VncAuth ; echo vncviewer-finished >/dev/$serialdev ", timeout => 60;
    wait_still_screen 4;
    assert_screen [qw(vnc_password_dialog vnc_password_dialog_incomplete)];
    if (match_has_tag 'vnc_password_dialog_incomplete') {
        # https://progress.opensuse.org/issues/158622
        assert_and_click 'vnc_password_dialog_incomplete', button => 'right';
        send_key 'esc';
        assert_screen 'vnc_password_dialog';
    }
    enter_cmd "$password";
    prepare_vnc;
    send_key 'super-left';
    wait_still_screen 2;

    # Send some vnc events to xev
    type_string 'events';
    mouse_set(80, 120);
    mouse_set(85, 125);
    mouse_click;

    send_key 'alt-f4';
    wait_serial('vncviewer-finished', $timeout) || die 'vncviewer not finished';
    enter_cmd 'exit';
    wait_still_screen 2;
}

sub clean {
    select_serial_terminal;
    # Terminate server
    if ($curr_vers < 0) {
        assert_script_run("sudo -u testuser vncserver -kill $display");
    }
    else {
        assert_script_run("systemctl stop vncserver\@$display");
    }
    # wait until all testuser processes are terminated after vnc session is clonsed
    assert_script_run('while pgrep -U testuser; do sleep 1; done', 200);
    script_run('userdel -r testuser');
    select_console('x11');
}

sub run {
    select_serial_terminal;
    my $xsession = is_tumbleweed ? 'gnome-session-xsession' : '';
    zypper_call("in tigervnc xorg-x11-Xvnc xev expect $xsession");

    # Check tigervnc version. Test will differ for versions under 1.12
    $tigervnc_vers = script_output("rpm -q tigervnc --qf '\%{version}'");
    $curr_vers = package_version_cmp($tigervnc_vers, '1.12.0');

    # add testuser and use testuser to setup vncserver
    assert_script_run("useradd -m -G tty,dialout,\$(stat -c %G /dev/$testapi::serialdev) testuser");
    assert_script_run(qq(expect -c 'spawn passwd testuser; expect "New password:"; send $options[1]->{pw}\\r; expect "Retype new password:"; send $options[1]->{pw}\\r; interact'));
    setup_vnc_server;

    # open xterm for xev
    x11_start_program('xterm');
    send_key "super-right";
    wait_still_screen 2;
    assert_screen 'vncviewer-console-right';
    assert_script_run("xauth add $display . $test_xauth");

    # Start vncviewer (rw & ro mode) and check if changes are processed by xev
    foreach my $opt (@options) {
        record_info 'Try ' . ($opt->{change} ? 'RW' : 'RO') . ' mode';

        # Start event watcher
        # trap is needed because ctrl-c would kill the whole process group (cmd ; cmd)
        # eg.
        #     xev -display $display -root | tee /tmp/xev_log ; echo xev-finished >/dev/$serialdev
        # will not work
        # Parentheses are needed to not populate trap to following commands. Add delay time on aarch64 because xev takes longer to finish or even hangs
        my $delay_time = (is_aarch64 && is_sle) ? 60 : is_ppc64le ? 5 : 1;
        enter_cmd "(trap 'echo xev-finished >/dev/$serialdev' SIGINT; xev -display $display -root | tee /tmp/xev_log); sleep $delay_time; ";

        # Repeat with RO/RW password
        generate_vnc_events $opt->{pw};

        # Close xev, re-try if needed on aarch64, increase timeout on aarch64 for wait_serial, see poo#119416
        send_key 'ctrl-c';
        wait_still_screen 2;
        # give a second chance to quit xev
        send_key 'ctrl-c' if (is_sle && is_aarch64) && ((check_screen 'need-to-close-again', $timeout) || (check_screen 'need-to-close-again-extra1', $timeout));
        my $message = 'xev not finished';
        $message .= ', performance issue on aarch64, see poo#120282 for more details' if (is_sle && is_aarch64);
        wait_serial('xev-finished', $timeout) || die $message;

        # Check if xev recorded events or not - RO/RW mode
        if ($opt->{change}) {
            assert_script_run '[ -s /tmp/xev_log ]';
        }
        else {
            assert_script_run 'wc -l /tmp/xev_log | grep "^0 "';
        }
        assert_script_run 'rm /tmp/xev_log';
    }
    send_key "alt-f4";    # close xev xterm

    if (check_var('DESKTOP', 'gnome')) {
        # Switch to desktop and run vncviewer
        select_console('x11');
        ensure_unlocked_desktop;
        x11_start_program('vncviewer');
        type_string("$display");
        send_key("ret");
        # We first test for a unsucessfull login
        assert_screen('tigervnc-desktop-login', $timeout);
        type_string("$wrong_password");
        send_key("ret");
        assert_screen('tigervnc-login-fail');
        if ($curr_vers >= 0) {
            send_key("tab");
            send_key(" ");
        }
        else {
            send_key("ret");
        }
        # Test for a sucessfull login. Note: vncviewer remembers the last address, don't type it again
        # sometimes screen is frozen with strange dialog like 'logged-as-priviled-user', there is no way to go further, so repeat these steps
        x11_start_program('vncviewer');
        send_key("ret");
        assert_screen([qw(tigervnc-desktop-login logged-as-priviled-user)]);
        if (match_has_tag 'logged-as-priviled-user') {
            record_soft_failure('poo#120282');
            send_key("alt-f4");
            select_console('root-console');
            assert_script_run("killall vncviewer");
            select_console('x11');
            ensure_unlocked_desktop;
            x11_start_program('vncviewer');
            send_key("ret");
            assert_screen('tigervnc-desktop-loggedin', $timeout);
            type_string("$options[1]->{pw}");
            send_key("ret");
        }
        else {
            type_string("$options[1]->{pw}");
            send_key("ret");
            prepare_vnc;
        }
        send_key("alt-f4");
        save_screenshot();
    } else {
        record_info("skipping graphical vnc tests (non-gnome desktop)");
    }
    # Done
    clean;
}

sub post_fail_hook {
    select_console 'log-console';
    # xev seems to hang, send control-c to ensure that we can actually type
    send_key "ctrl-c";
    upload_logs('/tmp/xev_log', failok => 1);
    upload_logs("/home/testuser/.local/state/tigervnc/susetest$display.log", failok => 1) unless $curr_vers < 0;
    upload_logs("/home/testuser/.vnc/susetest$display.log", failok => 1) if $curr_vers < 0;
    clean;
}

1;
