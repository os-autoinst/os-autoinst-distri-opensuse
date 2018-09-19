# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Avoid suprises later and run scheduled tasks explicitly, be it cron
#   jobs or systemd timer
# Maintainer: Stephan Kulow <coolo@suse.de>
# Tags: bsc#1017461, bsc#1063638

use base "consoletest";
use strict;
use testapi;
use utils 'assert_screen_with_soft_timeout';
use version_utils 'is_jeos';

sub settle_load {
    my $loop = 'read load dummy < /proc/loadavg  ; top -n1 -b| head -n30 ; test "${load/./}" -lt $limit && break ; sleep 5';
    script_run "limit=10; for c in `seq 1 200`; do $loop; done; echo TOP-DONE > /dev/$serialdev", 0;
    my $before = time;
    wait_serial('TOP-DONE', 1005) || die 'load not settled';
    # JeOS is different to SLE general as it extends the appliance's disk on first boot,
    # so the balance is a different challenge to SLE. Elapsed time is not necessary a key
    # measure here, responsiveness of the system is.
    record_soft_failure 'bsc#1063638' if (time - $before) > (is_jeos() ? 180 : 70) && get_var('SOFTFAIL_BSC1063638');
}

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # show dmesg output in console during cron run
    assert_script_run "dmesg -n 7";

    # Make sure there's no load before we trigger one via cron.
    settle_load;
    my $before = time;
    # run cron jobs or systemd timers which can affect system performance and mask systemd timers later
    assert_script_run('find /etc/cron.{hourly,daily,weekly,monthly} -type f -executable -exec echo cron job: {} \; -exec {} \;', 1000);
    my $systemd_tasks_cmd = 'echo "Triggering systemd timed service $i" && systemctl start $i';
    $systemd_tasks_cmd .= ' && systemctl mask $i.{service,timer}' unless get_var('SOFTFAIL_BSC1063638');
    assert_script_run(
        'for i in $(systemctl list-units --type=timer --state=active --no-legend | sed -e \'s/\(\S\+\)\.timer\s.*/\1/\'); do ' . $systemd_tasks_cmd . '; done');
    record_soft_failure 'bsc#1063638 - review I/O scheduling parameters of btrfsmaintenance' if (time - $before) > 60 && get_var('SOFTFAIL_BSC1063638');
    sleep 3;    # some head room for the load average to rise
    settle_load;

    # return dmesg output to normal
    assert_script_run "dmesg -n 1";

    # Detect btrfs balancing if filesystem is set to btrfs, or undef, as btrfs is default
    if (get_var('FILESYSTEM', 'btrfs') eq 'btrfs' || get_var('SOFTFAIL_BSC1063638')) {
        push @{$self->{serial_failures}}, {type => 'soft', message => 'bsc#1063638', pattern => qr/BTRFS info.*relocating/};
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
