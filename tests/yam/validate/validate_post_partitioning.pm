# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that post partition script was executed

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    assert_script_run("ls /etc/zypp/zypp.conf.rpmnew");
}

1;
