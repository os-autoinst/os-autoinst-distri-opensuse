# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate selinux in default installation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';

    assert_script_run("sestatus");
    assert_script_run("sestatus | grep 'SELinux status.*.enabled'");
    assert_script_run("sestatus | grep 'Current mode.*.enforcing'");
}

1;
