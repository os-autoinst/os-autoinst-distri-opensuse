# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

# Summary: Triggers SDAF cleanup.
# Executes 'remover.sh' script which is part of SDAF
# Removes deployer VM clone and it's resources
# Cleans up resources which are orphaned
# Post run hooks are generally disabled during normal module run so the infrastructure persists between test modules.
# To skip cleanup use OpenQA parameter 'SDAF_RETAIN_DEPLOYMENT'

use parent 'opensusebasetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use sles4sap::sap_deployment_automation_framework::deployment qw(serial_console_diag_banner);
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
