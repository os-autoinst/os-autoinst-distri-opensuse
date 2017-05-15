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
    # and encryption makes it even slower
    $timeout *= 2 if get_var('ENCRYPT');

    # workaround for yast popups and
    # detect "Wrong Digest" error to end test earlier
    my @tags = qw(rebootnow yast2_wrong_digest);
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
    # multipath installations seem to take longer (failed some time)
    $timeout *= 2 if check_var('MULTIPATH', 1);
    # on s390 we might need to install additional packages depending on the installation method
    if (check_var('ARCH', 's390x')) {
        push(@tags, 'additional-packages');
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

        if (match_has_tag("yast2_wrong_digest")) {
            die "Wrong Digest detected error, need to end test.";
        }

        if (match_has_tag("DIALOG-packages-notifications")) {
            send_key 'alt-o';    # ok
            next;
        }
        # can happen multiple times
        if (match_has_tag("ERROR-removing-package")) {
            # TODO we want to mark the current step as error but continue to
            # gather more data. Also we know how to apply to workaround but
            # still mark it as 'to be reviewed' if it appears
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
        if (match_has_tag('additional-packages')) {
            send_key 'alt-i';
        }
        last;
    }

    # Stop reboot countdown for e.g. uploading logs
    if (!get_var("REMOTE_CONTROLLER")) {
        # Depending on the used backend the initial key press to stop the
        # countdown might not be evaluated correctly or in time. In these
        # cases we try more often. As the timeout is 10 seconds trying more
        # than 4 times when waiting 2.5 seconds each time in between is not
        # helping. wait_still_screen can work with float numbers. A still time
        # of 2 seconds was leading to problems not detecting the countdown
        # still being active whereas 3 seconds would sometimes hit the timeout
        # even though the screen did not change after the initial stop button
        # press. Selecting 2.5 might be a good compromise
        my $counter = 4;
        while ($counter--) {
            send_key 'alt-s';
            last if wait_still_screen(2.5, 4, 99);
            record_info('workaround', "While trying to stop countdown no still screen could be detected, retrying up to $counter times more");
            die 'Failed to detect a still picture while waiting for stopped countdown.' if ($counter eq 1);
        }
        select_console 'install-shell';

        # check for right boot-device on s390x (zVM, DASD ONLY)
        if (check_var('BACKEND', 's390x') && !check_var('S390_DISK', 'ZFCP')) {
            if (script_run('lsreipl | grep 0.0.0150')) {
                die "IPL device was not set correctly";
            }
        }
        $self->get_ip_address();
        $self->save_upload_y2logs();
        select_console 'installation';
    }
    wait_screen_change {
        send_key 'alt-o';    # Reboot
    };

    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        # VNC connection to SUT (the 'sut' console) is terminated on Xen via svirt
        # backend and we have to re-connect *after* the restart, otherwise we end up
        # with stalled VNC connection. The tricky part is to know *when* the system
        # is already booting.
        reset_consoles;
        select_console 'svirt';
        sleep 4;
        select_console 'sut';
        # After restart connection to serial console seems to be closed. We have to
        # open it again.
        console('svirt')->attach_to_running({stop_vm => 1});
    }
}

1;
# vim: set sw=4 et:
