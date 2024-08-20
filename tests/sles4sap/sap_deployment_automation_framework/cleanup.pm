# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

# Summary: Triggers cleanup of the workload zone and SUT using SDAF automation.
# It also removes all SDAF test related files from deployer VM.
# Post run hooks are generally disabled during normal module run so the infrastructure persists between test modules.
# Cleanup is triggered only with B<SDAF_DO_CLEANUP> set to true, which is done by scheduling this module at the end of test flow.

use parent 'opensusebasetest';
use strict;
use testapi;
use warnings;
use serial_terminal qw(select_serial_terminal);
use sles4sap::sap_deployment_automation_framework::deployment
  qw(serial_console_diag_banner);
use sles4sap::sap_deployment_automation_framework::basetest qw(full_cleanup);

sub test_flags {
    return {fatal => 1};
}

sub run {
    select_serial_terminal;
    serial_console_diag_banner('Start: sdaf_cleanup.pm');
    full_cleanup();
    serial_console_diag_banner('End: sdaf_cleanup.pm');
}

sub post_fail_hook {
    record_info('CLEANUP FAIL');
    return;
}
1;
