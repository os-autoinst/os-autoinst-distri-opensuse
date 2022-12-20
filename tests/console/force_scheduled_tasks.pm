# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cronie btrfsmaintenance
# Summary: Avoid surprises later and run scheduled tasks explicitly, be it cron
#   jobs or systemd timer
# - Show dmesg output in console during cron run
# - Settle system load before starting tasks
# - Run cron jobs and systemd timers
# - Disable btrfs cron jobs symlinking them to /bin/true
# - Settle system load again
# Maintainer: Stephan Kulow <coolo@suse.de>
# Tags: bsc#1017461, bsc#1063638

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'assert_screen_with_soft_timeout';
use version_utils 'is_jeos';

sub settle_load {
    my $loop = 'read load dummy < /proc/loadavg  ; top -n1 -b| head -n30 ; test "${load/./}" -lt $limit && break ; sleep 5';
    script_run "limit=10; for c in `seq 1 200`; do $loop; done; echo TOP-DONE > /dev/$serialdev", 0;
    my $before = time;
    # Adding 2 extra minutes due to bsc#1178761 to ensure 200 iterations
    wait_serial('TOP-DONE', 1120) || die 'load not settled';
    # JeOS is different to SLE general as it extends the appliance's disk on first boot,
    # so the balance is a different challenge to SLE. Elapsed time is not necessary a key
    # measure here, responsiveness of the system is.
    record_soft_failure 'bsc#1063638' if (time - $before) > (is_jeos() ? 180 : 70) && get_var('SOFTFAIL_BSC1063638');
    if ((time - $before) > 1005) {
        record_soft_failure 'bsc#1178761';
        return 0;
    }
    return 1;
}

sub run {
    select_console 'root-console';

    # show dmesg output in console during cron run
    assert_script_run "dmesg -n 7";

    # Make sure there's no load before we trigger one via cron.
    my $is_settled = settle_load;
    my $before = time;
    # run cron jobs or systemd timers which can affect system performance and mask systemd timers later
    # if cron directories exist, try to run present cron jobs
    if (script_run('ls -a /etc/cron.{hourly,daily,weekly,monthly}') == 0) {
        assert_script_run('find /etc/cron.{hourly,daily,weekly,monthly} -type f -executable -exec echo cron job: {} \; -exec {} \;', 1000);
    }
    my $systemd_tasks_cmd = 'echo "Triggering systemd timed service $i"';
    $systemd_tasks_cmd .= ' && systemctl stop $i.timer && systemctl mask $i.timer' unless get_var('SOFTFAIL_BSC1063638');
    $systemd_tasks_cmd .= ' && systemctl start $i';
    assert_script_run(
'for i in $(systemctl list-units --type=timer --state=active --no-legend | sed -e \'s/\(\S\+\)\.timer\s.*/\1/\'); do ' . $systemd_tasks_cmd . '; done', 1000);
    record_soft_failure 'bsc#1063638 - review I/O scheduling parameters of btrfsmaintenance' if (time - $before) > 60 && get_var('SOFTFAIL_BSC1063638');
    # Disable cron jobs on older SLE12 by symlinking them to /bin/true
    if (!get_var('SOFTFAIL_BSC1063638') && script_run("! [ -d /usr/share/btrfsmaintenance/ ]")) {
        assert_script_run('find /usr/share/btrfsmaintenance/ -type f -exec ln -fs /bin/true {} \;', timeout => 300);
    }
    assert_script_run "sync";
    # avoid to settle the load if the first time was not settled due to bsc#1178761
    settle_load if $is_settled;

    # return dmesg output to normal
    assert_script_run "dmesg -n 1";
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
