# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Workaround to downgrade suseconnect-ng on 15-SP5 due to regression
# Maintainer: : QE-SAP <qe-sap@suse.de>

use base "y2_module_consoletest";
use testapi;
use utils;
use version_utils;

sub run {
    select_console 'root-console';

    # Workaround for bsc#1259906
    # 1.13.0 is the last known good version of suseconnect-ng
    if (is_sle('=15-SP5')) {
        record_soft_failure('bsc#1259906 - Downgrading suseconnect-ng due to regression');
        zypper_call('in --oldpackage --allow-downgrade suseconnect-ng-1.13.0');
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
