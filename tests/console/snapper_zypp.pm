# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Simple 'snapper-zypp-plugin' test
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Test::Assert 'assert_equals';

sub get_snapshot_id {
    return script_output("snapper ls | awk 'END {print \$1}'");
}

sub run_zypper_cmd {
    my $zypper_cmd = shift;
    my $before_snapshot_id = get_snapshot_id();
    zypper_call($zypper_cmd);
    my $after_snapshot_id = get_snapshot_id();
    record_info("Snapshot IDs", "Before: $before_snapshot_id, After: $after_snapshot_id");
    assert_equals($after_snapshot_id, $before_snapshot_id + 2, "Snapshot ID did not increment as expected");
}

sub run {
    select_serial_terminal;
    run_zypper_cmd("in htop");
    run_zypper_cmd("rm htop");
    run_zypper_cmd("dup");
}

1;
    

