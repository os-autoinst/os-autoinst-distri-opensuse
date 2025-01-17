# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Simple 'snapper-zypp-plugin' test
#       1. Ensure 'snapper-zypp-plugin' is installed
#       2. Get latest snapshot id number
#       3. Install/remove package
#       4. Ensure id number incremented by 2 (pre/post snapshots were created)
#       5. Ensure 'snapper diff' produces output related to package changes
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';
use Test::Assert 'assert_equals';

sub get_snapshot_id {
    my $snapshot_id = is_sle("<=12-SP5") ? '$3' : '$1';
    return script_output("snapper ls | awk 'END {print $snapshot_id}'");
}

sub run_zypper_cmd {
    my ($zypper_cmd, $package) = @_;
    my $before_snapshot_id = get_snapshot_id();
    zypper_call($zypper_cmd);
    my $after_snapshot_id = get_snapshot_id();
    record_info("Snapshot IDs", "Before: $before_snapshot_id, After: $after_snapshot_id");
    assert_equals($after_snapshot_id, $before_snapshot_id + 2, "Snapshot ID did not increment as expected");
    my $grep_pattern = "snapshot.*$before_snapshot_id.*$package.*$after_snapshot_id.*differ";
    assert_script_run("snapper diff $before_snapshot_id..$after_snapshot_id | grep '$grep_pattern'", fail_message => "No changes between snapshots for $package");
}

sub run {
    select_serial_terminal;
    my $package = (get_var('FLAVOR', '') =~ /^JeOS/ ? 'vim-small' : 'vim');

    assert_script_run("rpm -q snapper-zypp-plugin");
    run_zypper_cmd("rm $package", $package);
    run_zypper_cmd("in $package", $package);
}

1;
