# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check before/after IP setup
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "consoletest";

use strict;
use warnings;

use qam;
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;
    # we should get the same IP setup after every reboot, but for now
    # we can't assert this
    script_run("diff -u /tmp/ip_a_before.log /tmp/ip_a_after.log");
    save_screenshot;
    script_run("diff -u /tmp/ip_r_before.log /tmp/ip_r_after.log");
    save_screenshot;
}

1;
