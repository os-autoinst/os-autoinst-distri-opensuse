# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;
use utils;


sub run() {
    my $self = shift;

    # let's see how it looks at the beginning
    save_screenshot;

    if (!check_var('ARCH', 's390x')) {
        # verify there is a text console on tty1
        for (1 .. 6) {
            send_key 'ctrl-alt-f1';
            if (check_screen("tty1-selected", 5)) {
                last;
            }
        }
        if (!check_screen "tty1-selected", 5) {    #workaround for bsc#977007
            record_soft_failure "unable to switch to the text mode";
            send_key 'ctrl-alt-backspace';         #kill X and log in again
            send_key 'ctrl-alt-backspace';
            assert_screen 'displaymanager', 200;    #copy from installation/first_boot.pm
            if (get_var('DESKTOP_MINIMALX_INSTONLY')) {
                # return at the DM and log in later into desired wm
                return;
            }
            mouse_hide();
            if (get_var('DM_NEEDS_USERNAME')) {
                type_string $username;
            }
            if (match_has_tag("sddm")) {
                # make sure choose plasma5 session
                assert_and_click "sddm-sessions-list";
                assert_and_click "sddm-sessions-plasma5";
                assert_and_click "sddm-password-input";
            }
            else {
                send_key "ret";
                wait_idle;
            }
            type_string "$password";
            send_key "ret";
            send_key_until_needlematch "tty1-selected", "ctrl-alt-f1", 6, 5;
        }
    }

    # init
    select_console 'root-console';

    type_string "chown $username /dev/$serialdev\n";
    # Export the existing status of running tasks for future reference (fail would export it again)
    script_run "ps axf > /tmp/psaxf.log";

    # openSUSE 13.2's (and earlier) systemd has broken rules for virtio-net, not applying predictable names (despite being configured)
    # A maintenance update breaking networking names sounds worse than just accepting that 13.2 -> TW breaks
    # At this point, the system has been upadted, but our network interface changes name (thus we lost network connection)
    my @old_hdds = qw/openSUSE-12.1 openSUSE-12.2 openSUSE-12.3 openSUSE-13.1-gnome openSUSE-13.2/;
    if (grep { check_var('HDDVERSION', $_) } @old_hdds) {    # copy eth0 network config to ens4
        script_run("cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-ens4");
        script_run("/sbin/ifup ens4");
    }

    # Just after the setup: let's see the network configuration
    script_run "ip addr show";
    save_screenshot;

    # Stop packagekit
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";
    # Installing a minimal system gives a pattern conflicting with anything not minimal
    # Let's uninstall 'the pattern' (no packages affected) in order to be able to install stuff
    script_run "zypper -n rm patterns-openSUSE-minimal_base-conflicts";
    # Install curl and tar in order to get the test data
    assert_script_run "zypper -n install curl tar";

    # upload_logs requires curl, but we wanted the initial state of the system
    upload_logs "/tmp/psaxf.log";
    save_screenshot;

    $self->clear_and_verify_console;

    select_console 'user-console';

    assert_script_run "curl -L -v -f " . autoinst_url('/data') . " > test.data";
    assert_script_run " cpio -id < test.data";
    script_run "ls -al data";

    save_screenshot;
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
