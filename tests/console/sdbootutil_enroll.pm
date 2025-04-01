# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Package: sdbootutil
# Summary: Enroll TPM to unlock encrypted disk
# Maintainer: Santiago Zarate <santiago.zarate@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('in expect');
    assert_script_run("expect -c 'spawn sdbootutil enroll --method tpm2; expect \"Password for /dev/.*:\";send $testapi::password\\n;interact'");
    set_var("RUNTIME_TPM_ENROLLED", 1);
}

1;
