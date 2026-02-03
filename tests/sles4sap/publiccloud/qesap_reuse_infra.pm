# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Reuse qe-sap-deployment infrastructure preserved from previous test run.
#
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/qesap_reuse_infra.pm - Reuse existing infrastructure.

=head1 DESCRIPTION

This module allows reusing an existing cloud infrastructure from a previous test run,
identified by B<QESAP_DEPLOYMENT_IMPORT>. It imports the instance data, disables
cleanup to preserve the environment, and configures necessary variables for the
current test execution.

Its primary tasks are:

- Disable cleanup (sets B<QESAP_NO_CLEANUP> and B<QESAP_NO_CLEANUP_ON_FAILURE>).
- Unset B<QESAP_DEPLOYMENT_EXPORT> to prevent inheritance issues.
- Set B<SAP_SIDADM> based on B<INSTANCE_SID>.
- Import instance data using the test ID from B<QESAP_DEPLOYMENT_IMPORT>.
- Initialize the provider and instance data structures.

=head1 SETTINGS

=over

=item B<QESAP_DEPLOYMENT_IMPORT>

(Required) The Test ID of the previous run from which to import the infrastructure.

=item B<QESAP_NO_CLEANUP>

If this variable is set to a true value, the cleanup process will be skipped.
This module explicitly sets it to '1' to preserve imported infrastructure.

=item B<INSTANCE_SID>

The SAP System ID, used to determine the `sidadm` username.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use base 'sles4sap::publiccloud_basetest';
use testapi;
use publiccloud::ssh_interactive 'select_host_console';
use serial_terminal 'select_serial_terminal';
use sles4sap::publiccloud;
use sles4sap::qesap::qesapdeployment;

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
    my $instances = create_instance_data(provider => $provider);
    $self->{instances} = $run_args->{instances} = $instances;

    record_info('IMPORT OK', 'Instance data imported.');
}

1;
