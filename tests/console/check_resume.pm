# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify that "resume=" kernel parameter is absent in the list of default parameters on Sle15-SP2

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    assert_script_run("grep -v 'resume=' /proc/cmdline", fail_message => "resume parameter found in /proc/cmdline");
}

1;
