# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: s390 DASD Disk activation test
# Maintainer: Matthias Griessmeier <mgriessmeier@suse.com>

use base "y2logsstep";
use strict;
use testapi;

sub workaround_broken_disk_activation {
    my $r;
    record_soft_failure 'bsc#1055871';
    select_console 'install-shell';

    $r = script_run("dasd_configure 0.0.0150 1");
    die "DASD in undefined state" unless (defined($r) && ($r == 0 || $r == 8));

    $r = script_run("lsdasd");
    assert_screen("ensure-dasd-exists");
    die "dasd_configure died with exit code $r" unless (defined($r) && $r == 0);

    # if formatting is supposed to do inside yast, do it here as workaround
    if (get_var('FORMAT_DASD_YAST')) {
        $r = script_run("echo yes | dasdfmt -b 4096 -p /dev/dasda", 1200);
        die "dasdfmt died with exit code $r" unless (defined($r) && $r == 0);
    }
    select_console 'installation';
}

sub format_dasd {
    while (check_screen 'process-dasd-format') {
        diag("formatting DASD ...");
        sleep 20;
    }
}

sub run {
    # use zfcp as install disk
    if (check_var('S390_DISK', 'ZFCP')) {
        assert_screen 'disk-activation-zfcp';

        wait_screen_change { send_key 'alt-z' };

        # workaround for bsc#1055871
        # check if we're still on the overview page
        if (check_screen('disk-activation-zfcp', 0)) {
            workaround_broken_disk_activation;
        }
        else {
            assert_screen 'zfcp-disk-management';
            send_key 'alt-a';
            assert_screen 'zfcp-add-device';
            send_key $cmd{next};

            # use allow_lun_scan
            assert_screen 'zfcp-popup-scan';
            send_key 'alt-o';

            assert_screen 'zfcp-disk-management';
            assert_screen 'zfcp-activated';
            send_key $cmd{next};
            wait_still_screen 5;
        }
    }
    else {
        # use default DASD as install disk
        assert_screen 'disk-activation', 15;
        wait_screen_change { send_key 'alt-d' };

        # workaround for bsc#1055871
        # check if we're still on the overview page
        if (check_screen('disk-activation', 0)) {
            workaround_broken_disk_activation;
        }
        else {
            assert_screen 'dasd-disk-management';

            # we need to type backspace to delete the content of the input field in textmode
            if (check_var("VIDEOMODE", "text")) {
                send_key 'alt-m';    # minimum channel ID
                for (1 .. 9) { send_key "backspace"; }
                type_string '0.0.0150';
                send_key 'alt-x';    # maximum channel ID
                for (1 .. 9) { send_key "backspace"; }
                type_string '0.0.0150';
                send_key 'alt-f';    # filter button
                assert_screen 'dasd-unselected';
                send_key 'alt-s';    # select all
                assert_screen 'dasd-selected';
                send_key 'alt-a';    # perform action button
                assert_screen 'action-list';
                send_key 'alt-a';    # activate
            }
            else {
                send_key 'alt-m';    # minimum channel ID
                type_string '0.0.0150';
                send_key 'alt-x';    # maximum channel ID
                type_string '0.0.0150';
                send_key 'alt-f';    # filter button
                assert_screen 'dasd-unselected';
                send_key 'alt-s';    # select all
                assert_screen 'dasd-selected';
                send_key 'alt-a';    # perform action button
                assert_screen 'action-list';
                send_key 'a';        # activate
            }

            # sometimes it happens, that the DASD is in a unstable state, so
            # if the systems wants to format the DASD by itself, do it.
            if (check_screen 'dasd-format-device', 10) {    # format device pop-up
                send_key 'alt-o';                           # continue
                format_dasd;
            }

            # format DASD if the variable is that, because we format it usually pre-installation
            elsif (get_var('FORMAT_DASD_YAST')) {
                send_key 'alt-s';                           # select all
                assert_screen 'dasd-selected';
                send_key 'alt-a';                           # perform action button
                if (check_screen 'dasd-device-formatted') {
                    assert_screen 'action-list';
                    send_key 'f';
                    send_key 'f';                           # Pressing f twice because of bsc#940817
                    send_key 'ret';
                    assert_screen 'confirm-dasd-format';    # confirmation popup
                    send_key 'alt-y';
                    format_dasd;
                }
            }
            assert_screen 'dasd-active';
            send_key $cmd{next};
        }
    }
    assert_screen 'disk-activation', 15;
    send_key $cmd{next};

    # check for multipath popup
    if (check_screen('detected-multipath', 5)) {
        wait_screen_change { send_key 'alt-y' };
        send_key 'alt-n';
    }
}

1;
# vim: set sw=4 et:
