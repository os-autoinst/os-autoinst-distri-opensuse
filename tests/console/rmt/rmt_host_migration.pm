# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rmt-server
# Summary: This tests rmt server can work before and after migration
#    Add rmt configuration test and basic configuration via
#    rmt-wizard, enable repo, check repo at base system, then upgrade
#    to latest one. It can still work fine.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use repo_tools;

sub run {
    select_console 'root-console';

    if (check_var('VERSION', get_required_var('ORIGIN_SYSTEM_VERSION'))) {
        rmt_wizard();
        # Sync from SCC
        rmt_sync;
        # Enable one product
        assert_script_run("rmt-cli product enable sle-module-live-patching/15/x86_64");
    }

    # After migation, need do rmt sync again
    rmt_sync if (check_var('VERSION', get_required_var('UPGRADE_TARGET_VERSION')));

    # Before and after migration, both need rmt gets expected product
    assert_script_run("rmt-cli product list | grep sle-module-live-patching/15/x86_64");
}

1;
