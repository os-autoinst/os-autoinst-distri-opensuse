# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate medium integrity check has successfully finished during booting phase.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run("journalctl -b | grep \"Finished Installation medium integrity check.\"", timeout => 60);
}

1;
