# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

# Summary: Triggers cleanup of the workload zone and SUT using SDAF automation.
# It also removes all SDAF test related files from deployer VM.
# Post run hooks are generally disabled during normal module run so the infrastructure persists between test modules.
# Cleanup is triggered only with B<SDAF_DO_CLEANUP> set to true, which is done by scheduling this module at the end of test flow.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';
use strict;
use testapi;
use warnings;
use sles4sap::sap_deployment_automation_framework::deployment;
use sles4sap::console_redirection;

sub test_flags {
    return {fatal => 1};
}

sub run {
    serial_console_diag_banner('end: sdaf_cleanup.pm');
    if (get_var('SDAF_RETAIN_DEPLOYMENT')) {
        record_info('Cleanup OFF', 'OpenQA variable "SDAF_RETAIN_DEPLOYMENT" is active, skipping cleanup.');
        return;
    }

    # Cleanup SDAF files form Deployer VM
    connect_target_to_serial();
    load_os_env_variables();
    az_login();
    sdaf_cleanup();
    disconnect_target_from_serial();
}

1;
