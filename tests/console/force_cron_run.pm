# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Avoid suprises later and run the cron jobs explicitly
# Maintainer: Stephan Kulow <coolo@suse.de>
# Tags: bsc#1017461

use base "consoletest";
use strict;
use testapi;
use utils qw(assert_screen_with_soft_timeout is_jeos);

sub settle_load {
    script_run "top; echo TOP-DONE-\$? > /dev/$serialdev", 0;
    # JeOS is different to SLE general as it extends the appliance's disk on first boot,
    # so the balance is a different challenge to SLE. Elapsed time is not necessary a key
    # measure here, responsiveness of the system is.
    assert_screen_with_soft_timeout('top-load-decreased', soft_timeout => is_jeos() ? 180 : 30, bugref => 'bsc#1017461', timeout => 1000);
    send_key 'q';
    wait_serial 'TOP-DONE' || die 'top did not quit?';
}

sub run {
    select_console 'root-console';

    if (script_run 'grep -w mail /etc/group') {
        record_soft_failure 'bsc#1061838 - Group "mail" not found';
        return;
    }

    # show dmesg output in console during cron run
    assert_script_run "dmesg -n 7";

    # Make sure there's no load before we trigger one via cron.
    settle_load;
    my $before = time;
    assert_script_run "bash -x /usr/lib/cron/run-crons", 1000;
    record_soft_failure 'bsc#1017461 - long running btrfs cron jobs can make system unresponsive' if (time - $before) > 60;
    sleep 3;    # some head room for the load average to rise
    settle_load;

    # return dmesg output to normal
    assert_script_run "dmesg -n 1";
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
