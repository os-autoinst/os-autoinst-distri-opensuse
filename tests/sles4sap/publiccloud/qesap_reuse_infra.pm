# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Reuse qe-sap-deployment infrastructure preserved from previous test run.
# https://github.com/SUSE/qe-sap-deployment

use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings;
use testapi;
use publiccloud::ssh_interactive 'select_host_console';
use serial_terminal 'select_serial_terminal';
use sles4sap_publiccloud;
use qesapdeployment;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    my $test_id = get_required_var('QESAP_DEPLOYMENT_IMPORT');

    # Disable cleanup to keep resources running
    set_var('QESAP_NO_CLEANUP', '1');
    set_var('QESAP_NO_CLEANUP_ON_FAILURE', '1');
    # This prevents variable being inherited from cloned job
    set_var('QESAP_DEPLOYMENT_EXPORT', '');
    set_var('SAP_SIDADM', lc(get_var('INSTANCE_SID') . 'adm'));

    # Select console on the host (not the PC instance) to reset 'TUNNELED',
    # otherwise select_serial_terminal() will be failed
    select_host_console();
    select_serial_terminal();

    qesap_import_instances($test_id);

    my $provider = $self->provider_factory();
    my $instances = create_instance_data($provider);
    $self->{instances} = $run_args->{instances} = $instances;

    record_info('IMPORT OK', 'Instance data imported.');
}

1;
