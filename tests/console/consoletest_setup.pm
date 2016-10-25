# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare console for console tests
# Maintainer: Oliver Kurz <okurz@suse.com>

use base "consoletest";
use testapi;
use utils;
use strict;

# Summary: console test pre setup, stoping and disabling packagekit, install curl and tar to get logs and so on
# Maintainer: Oliver Kurz <okurz@suse.de>

sub run() {
    my $self = shift;

    # Without this login name and password won't get to the system. They get
    # lost somewhere. Applies for all systems installed via svirt, but zKVM.
    if (check_var('BACKEND', 'svirt') and !check_var('ARCH', 's390x')) {
        wait_idle;
    }

    # let's see how it looks at the beginning
    save_screenshot;

    # Special keys like Ctrl-Alt-Fx does not work on Hyper-V atm. Alt-Fx however do.
    my $tty1_key = 'ctrl-alt-f1';
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $tty1_key = 'alt-f1';
    }

    if (!check_var('ARCH', 's390x')) {
        # verify there is a text console on tty1
        for (1 .. 6) {
            send_key $tty1_key;
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
            send_key_until_needlematch "tty1-selected", $tty1_key, 6, 5;
        }
    }

    # init
    select_console 'root-console';

    type_string "chown $username /dev/$serialdev\n";
    # Export the existing status of running tasks and system load for future reference (fail would export it again)
    script_run "ps axf > /tmp/psaxf.log";
    script_run "cat /proc/loadavg > /tmp/loadavg_consoletest_setup.txt";

    # Just after the setup: let's see the network configuration
    script_run "ip addr show";
    save_screenshot;

    # Stop packagekit
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";
    # Installing a minimal system gives a pattern conflicting with anything not minimal
    # Let's uninstall 'the pattern' (no packages affected) in order to be able to install stuff
    script_run 'rpm -qi patterns-openSUSE-minimal_base-conflicts && zypper -n rm patterns-openSUSE-minimal_base-conflicts';
    # Install curl and tar in order to get the test data
    assert_script_run "zypper -n install curl tar";

    # upload_logs requires curl, but we wanted the initial state of the system
    upload_logs "/tmp/psaxf.log";
    upload_logs "/tmp/loadavg_consoletest_setup.txt";

    # BSC#997263 - VMware screen resolution defaults to 800x600
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        assert_script_run("sed -ie '/GFXMODE=/s/=.*/=1024x768x32/' /etc/default/grub");
        assert_script_run("sed -ie '/GFXPAYLOAD_LINUX=/s/=.*/=1024x768x32/' /etc/default/grub");
        assert_script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");
    }

    # https://fate.suse.com/320347 https://bugzilla.suse.com/show_bug.cgi?id=988157
    if (check_var('NETWORK_INIT_PARAM', 'ifcfg=eth0=dhcp')) {
        # grep all also compressed files e.g. y2log-1.gz
        assert_script_run 'less /var/log/YaST2/y2log*|grep "Automatic DHCP configuration not started - an interface is already configured"';
    }

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
