# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate TPM FDE.
# Testing for the presence of a TPM.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call("in tpm2.0-tools");
    assert_script_run("fdectl tpm-present");
}

1;
