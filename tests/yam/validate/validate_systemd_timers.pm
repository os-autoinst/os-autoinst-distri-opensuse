# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate systemd timers.
# 1. use systemd-run to create transient .timer units that touches a file after 30 seconds
# 2. verify that the file is created in the interval of time expected
# 3. verify that the on-shot timer is not listed anymore

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    script_output("systemctl list-timers");
    my $output_systemd_run = script_output("systemd-run --on-active=30 /bin/touch /tmp/foo 2>&1");
    my ($service) = $output_systemd_run =~ /Will run service as unit:\s+(\S+\.service)/;
    validate_script_output_retry("systemctl list-timers", sub { m/\b$service\b/ });
    script_retry("ls -l /tmp/foo");
    validate_script_output("systemctl list-timers", sub { !m/\b$service\b/ });
}

1;
