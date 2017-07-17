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
use utils;
use ipmi_backend_utils;

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

# Stop countdown and check success by waiting screen change without performing an action
sub wait_countdown_stop {
    my $stilltime = shift;
    send_key 'alt-s';
    return wait_screen_change(undef, $stilltime);
}

sub run {
    my $self = shift;
    # NET isos are slow to install
    my $timeout = 2000;
    # and encryption makes it even slower
    $timeout *= 2 if get_var('ENCRYPT');

    # workaround for yast popups and
    # detect "Wrong Digest" error to end test earlier
    my @tags = qw(rebootnow yast2_wrong_digest yast2_package_retry);
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

        if (match_has_tag("yast2_package_retry")) {
            record_soft_failure "boo#1018262 - retry failing packages";
            send_key 'alt-y';    # retry
            die "boo#1018262 - seems to be stuck on retry" unless wait_screen_change { sleep 4 };
            next;
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
        if (match_has_tag('additional-packages')) {
            send_key 'alt-i';
        }
        last;
    }

    # Stop reboot countdown for e.g. uploading logs
    if (!get_var("REMOTE_CONTROLLER")) {
        # Depending on the used backend the initial key press to stop the
        # countdown might not be evaluated correctly or in time. In these
        # cases we keep hitting the keys until the countdown stops.
        my $counter = 10;
        while ($counter-- and wait_countdown_stop(3)) {
            record_info('workaround', "While trying to stop countdown we saw a screen change, retrying up to $counter times more");
        }
        select_console 'install-shell';

        # check for right boot-device on s390x (zVM, DASD ONLY)
        if (check_var('BACKEND', 's390x') && !check_var('S390_DISK', 'ZFCP')) {
            if (script_run('lsreipl | grep 0.0.0150')) {
                die "IPL device was not set correctly";
            }
        }
        # while technically SUT has a different network than the BMC
        # we require ssh installation anyway
        if (check_var('BACKEND', 'ipmi')) {
            use_ssh_serial_console;
            # set serial console for xen
            set_serial_console_on_xen("/mnt") if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen"));
        }
        else {
            # avoid known issue in FIPS mode: bsc#985969
            $self->get_ip_address();
        }
        $self->save_upload_y2logs();
        select_console 'installation';
    }
    # kill the ssh connection before triggering reboot
    console('root-ssh')->kill_ssh if check_var('BACKEND', 'ipmi');
    wait_screen_change {
        send_key 'alt-o';    # Reboot
    };

    assert_shutdown_and_restore_system if check_var('VIRSH_VMM_FAMILY', 'xen');
}

1;
# vim: set sw=4 et:
