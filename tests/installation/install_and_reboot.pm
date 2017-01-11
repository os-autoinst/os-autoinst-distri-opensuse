# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Monitor installation progress and wait for "reboot now" dialog,
#   collecting logs from the installation system just before we try to reboot
#   into the installed system
# Maintainer: Oliver Kurz <okurz@suse.de>

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
    my @tags = qw(rebootnow);
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
        if (get_var('LIVECD') && $screenlock_previously_detected) {
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

    # Upload logs before reboot
    if (!get_var("REMOTE_CONTROLLER")) {
        do {
            send_key 'alt-s';
        } until (wait_still_screen(2, 4));
        select_console 'install-shell';
        assert_screen 'inst-console';
        $self->get_ip_address();
        $self->save_upload_y2logs();
        select_console 'installation';
        assert_screen 'rebootnow';
    }
    wait_screen_change {
        send_key 'alt-o';    # Reboot
    };

    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        reset_consoles;
        # VNC connection to SUT (the 'sut' console) is terminated on Xen via svirt
        # backend and we have to re-connect *after* the restart, otherwise we end up
        # with stalled VNC connection. The tricky part is to know *when* the system
        # is already booting.
        sleep 7;
        select_console 'sut';
    }
}

1;
# vim: set sw=4 et:
