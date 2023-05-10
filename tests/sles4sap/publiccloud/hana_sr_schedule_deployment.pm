# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for scheduling qesap-deployment related modules.

package hana_sr_schedule_deployment;

use base 'sles4sap_publiccloud_basetest';
use main_common 'loadtest';
use strict;
use warnings FATAL => 'all';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    if (get_var('QESAP_DEPLOYMENT_IMPORT')) {
        loadtest('sles4sap/publiccloud/qesap_reuse_infra', name => 'prepare_existing_infrastructure', run_args => $run_args, @_);
        loadtest('sles4sap/publiccloud/qesap_ansible', name => 'verify_infrastructure', run_args => $run_args, @_);
    }
    else {
        loadtest('sles4sap/publiccloud/qesap_terraform', name => 'deploy_qesap_terraform', run_args => $run_args, @_);
        loadtest('sles4sap/publiccloud/qesap_ansible', name => 'deploy_qesap_ansible', run_args => $run_args, @_);
    }
}

1;
