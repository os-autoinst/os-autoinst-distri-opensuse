# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: auto import gpg keys
# Auto import gpg keys, useful when we re-launch the test suite after the gpg key for maintenance repositories have expired (eg next day after initial run).
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "y2_module_consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('--gpg-auto-import-keys ref');
}

1;
