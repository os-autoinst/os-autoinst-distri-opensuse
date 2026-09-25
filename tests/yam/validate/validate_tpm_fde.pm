# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate TPM FDE.
# Testing for the presence of a TPM.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;

sub run {
    select_console 'root-console';
    # Enable the first repo - flavor=Full has only 1 repo. In SLE16.0
    # it's 'SLES', but in 16.1 it's 'Installation'
    zypper_call("mr -e 1") if (check_var('FLAVOR', 'Full'));
    zypper_call("in tpm2.0-tools");
    assert_script_run("fdectl tpm-present", timeout => 300);
}

1;
