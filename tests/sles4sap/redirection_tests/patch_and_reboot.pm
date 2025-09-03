# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module performs ENSA2 B<'Kill sapinstance'> test scenario.

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

package patch_and_reboot;
use testapi;
use serial_terminal qw(select_serial_terminal);


sub run {
    my ($self, $run_args) = @_;
    record_info('Maintenance on', '');
    record_info('Patching', '');
    record_info('Rebooting', '');
    record_info('Maintenance off', '');
    
}

1;