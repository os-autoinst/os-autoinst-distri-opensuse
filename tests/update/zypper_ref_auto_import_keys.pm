# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: auto import gpg keys
# Auto import gpg keys, useful when we re-launch the test suite after the gpg key for maintenance repositories have expired (eg next day after initial run).
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('--gpg-auto-import-keys ref');
}

1;
