# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate TPM FDE.
# Testing for the presence of a TPM.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call("in tpm2.0-tools");
    assert_script_run("fdectl tpm-present");
}

1;
