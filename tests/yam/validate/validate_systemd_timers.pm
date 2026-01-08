# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate systemd timers.
# 1. use systemd-run to create transient .timer units that touches a file after 30 seconds
# 2. verify that the file is created in the interval of time expected
# 3. verify that the on-shot timer is not listed anymore

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    script_output("systemctl list-timers");
    my $on_active_sec = 30;
    my $output_systemd_run = script_output('echo Now: $(date +%s); ' . "systemd-run --on-active=$on_active_sec --timer-property=AccuracySec=100ms /bin/touch /tmp/foo 2>&1");
    my ($start_time) = $output_systemd_run =~ /Now: (\d+)/;
    my ($service) = $output_systemd_run =~ /Will run service as unit:\s+(\S+\.service)/;
    validate_script_output_retry("systemctl list-timers", sub { m/\b$service\b/ });
    script_retry("ls -l /tmp/foo");
    my $birth_time = script_output('stat -c %W /tmp/foo');
    my $elapsed_time = $birth_time - $start_time;
    validate_script_output("systemctl list-timers", sub { !m/\b$service\b/ });
    record_info("stat /tmp/foo", "Scheduled: $start_time.\nCreated: $birth_time.\nElapsed: $elapsed_time secs");
    die("elapsed_time ($elapsed_time) is greater than  OnActiveSec ($on_active_sec)!") if $elapsed_time > $on_active_sec + 1;
}

1;
