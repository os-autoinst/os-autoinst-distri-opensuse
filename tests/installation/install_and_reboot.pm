# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Rename livecdreboot, moved grub code in grub_test.pm
#    Livecdreboot test name was unclear, renamed it in to install_and_reboot.
#    The code concerning grub test has moved to new test grub_test.pm
#    Main pm adapted for the new grub_test.pm
#    In first_boot.pm added get_var(boot_into_snapshot) for assert linux-terminal,
#    since after booting on snapshot, only a terminal interface is given, not GUI.
#
#    Issues on progress: 9716,10286,10164
# G-Maintainer: dmaiocchi <dmaiocchi@suse.com>

use strict;
use base "y2logsstep";
use testapi;
use lockapi;


sub handle_livecd_screenlock {
    record_soft_failure 'boo#994044: Kde-Live net installer is interrupted by screenlock';
    diag('unlocking screenlock with no password in LIVECD mode');
    do {
        # password and unlock button seem to be not in focus so switch to
        # the only 'window' shown, tab over the empty password field and
        # confirm unlocking
        send_key 'alt-tab';
        send_key 'tab';
        send_key 'ret';
    } while (check_screen('screenlock', 20));
    save_screenshot;
    # can take a long time until the screen unlock happens as the
    # system is busy installing.
    assert_screen('yast-still-running', 120);
}

sub run() {
    my $self = shift;
    # NET isos are slow to install
    my $timeout = 2000;

    # workaround for yast popups
    my @tags = qw/rebootnow/;
    if (get_var("UPGRADE")) {
        push(@tags, "ERROR-removing-package");
        push(@tags, "DIALOG-packages-notifications");
        $timeout = 5500;    # upgrades are slower
    }
    if (get_var('LIVECD')) {
        push(@tags, 'screenlock');
    }
    # SCC might mean we install everything from the slow internet
    if (check_var('SCC_REGISTER', 'installation')) {
        $timeout = 5500;
    }
    my $keep_trying                    = 1;
    my $screenlock_previously_detected = 0;
    my $mouse_x                        = 1;
    while ($keep_trying) {
        # try gracefully on aarch64 because of boo#982136
        if (check_var('ARCH', 'aarch64')) {
            my $ret = check_screen \@tags, $timeout;
            if (!$ret) {
                die 'timed out installation even after retrying' unless $keep_trying;
                record_soft_failure 'boo#982136: timed out after ' . $timeout . 'seconds, trying once more';
                $keep_trying = 0;
                next;
            }
        }
        elsif (get_var('LIVECD') && $screenlock_previously_detected) {
            my $ret = check_screen \@tags, 30;
            if (!$ret) {
                diag('installation not finished, move mouse around a bit to keep screen unlocked');
                $mouse_x = ($mouse_x + 10) % 1024;
                mouse_set($mouse_x, 1);
                next;
            }
            $timeout -= 30;
            diag("left total install_and_reboot timeout: $timeout");
            if ($timeout <= 0) {
                assert_screen \@tags;
            }
        }
        else {
            assert_screen \@tags, $timeout;
        }
        if (match_has_tag("DIALOG-packages-notifications")) {
            send_key 'alt-o';    # ok
            next;
        }
        # can happen multiple times
        if (match_has_tag("ERROR-removing-package")) {
            record_soft_failure;
            send_key 'alt-d';    # details
            assert_screen 'ERROR-removing-package-details';
            send_key 'alt-i';    # ignore
            next;
        }
        if (get_var('LIVECD') and match_has_tag('screenlock')) {
            handle_livecd_screenlock;
            $screenlock_previously_detected = 1;
            next;
        }
        last;
    }

    if (!get_var("REMOTE_CONTROLLER")) {
        send_key 'alt-s';        # Stop the reboot countdown
        select_console 'install-shell';
        $self->get_ip_address();
        $self->save_upload_y2logs();
        select_console 'installation';
        assert_screen 'rebootnow';
    }
    send_key 'alt-o';
}

1;
# vim: set sw=4 et:
