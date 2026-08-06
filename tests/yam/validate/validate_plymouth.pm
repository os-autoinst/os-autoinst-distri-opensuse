# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate if plymouth is configured correctly in the bootloader
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    assert_script_run("grep splash=silent /proc/cmdline");
}

1;
