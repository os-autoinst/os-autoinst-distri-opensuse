# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Deploy public cloud infrastructure using terraform.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/qesap_terraform.pm - Deploy public cloud infrastructure using terraform

=head1 DESCRIPTION

This module executes terraform commands to provision public cloud infrastructure for QE-SAP deployments.
It includes retry logic to handle common transient CSP errors (like concurrent peering operations or internal errors)
and implements specific workarounds for GCP environments.

Its primary tasks are:

=over

=item - Execute terraform deployment with parallelism and logging.

=item - Implement conditional retries for known transient cloud provider errors.

=item - Apply GCP-specific workarounds for Ansible password issues.

=item - Flag terraform as applied in the provider object.

=back

=head1 SETTINGS

=over

=item B<HANASR_TERRAFORM_PARALLEL>

(Optional) Specifies the degree of parallelism for terraform.

=item B<PUBLIC_CLOUD_PROVIDER>

CSP provider name (used for GCP-specific logic).

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

package qesap_terraform;

use base 'sles4sap::publiccloud_basetest';
use testapi;
use publiccloud::ssh_interactive 'select_host_console';
use serial_terminal 'select_serial_terminal';
use publiccloud::utils qw(is_gce);
use sles4sap::qesap::qesapdeployment;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    my $provider = $run_args->{my_provider} or die "No provider in run_args";
    $self->{provider} = $provider;

    # Select console on the host (not the PC instance) to reset 'TUNNELED',
    # otherwise select_serial_terminal() will be failed
    select_host_console();
    select_serial_terminal();

    my %retry_args = (
        logname => 'qesap_exec_terraform.log.txt',
        verbose => 1,
        timeout => 3600,
        error_list => [
            'An internal execution error occurred. Please retry later',
            'There is a peering operation in progress'
        ],
        destroy => 0);
    # Retrying terraform more times in case of GCP, to handle concurrent peering attempts
    $retry_args{retries} = is_gce() ? 5 : 2;
    $retry_args{cmd_options} = '--parallel ' . get_var('HANASR_TERRAFORM_PARALLEL') if get_var('HANASR_TERRAFORM_PARALLEL');

    my @ret = qesap_terraform_conditional_retry(%retry_args);
    die 'Terraform deployment FAILED. Check "qesap*" logs for details.' if ($ret[0]);

    # Sleep $N for fixing ansible "Missing sudo password" issue on GCP
    if (is_gce()) {
        sleep 60;
        record_info('Workaround: "sleep 60" for fixing ansible "Missing sudo password" issue on GCP');
    }

    $provider->terraform_applied(1);
}

1;
