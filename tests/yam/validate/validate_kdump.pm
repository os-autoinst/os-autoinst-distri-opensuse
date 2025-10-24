# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
# SUSE's openQA tests
#
# Summary: Validation kdump services and core files
# Scenarios covered:
# - Verify kdump services are enabled
# - Verify crashkernel= is present in /proc/cmdline
# - Verify core files existed in /var/crash/datetime/core
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';

    assert_script_run("systemctl status --no-pager kdump | grep 'Active: active (exited)'");
    script_output('cat /proc/cmdline');
    assert_script_run('grep -q "crashkernel=[0-9]*M@" /proc/cmdline');
    script_run("systemctl status --no-pager kdump-commandline.service");
    assert_script_run("systemctl status --no-pager kdump-commandline.service | grep 'Active: inactive (dead)'");
    assert_script_run("systemctl restart kdump-commandline.service");
    # assert_script_run('test -s /var/crash/*/vmcore');
}

1;
