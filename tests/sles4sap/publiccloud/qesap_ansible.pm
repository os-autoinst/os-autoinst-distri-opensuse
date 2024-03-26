# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Execute ansible deployment using qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

use strict;
use warnings;
use base 'sles4sap_publiccloud_basetest';
use testapi;
use publiccloud::utils;
use sles4sap_publiccloud;
use qesapdeployment;
use serial_terminal 'select_serial_terminal';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    my $ha_enabled = get_required_var('HA_CLUSTER') =~ /false|0/i ? 0 : 1;
    select_serial_terminal;
    # mark as done in advance and also in case of
    # QESAP_DEPLOYMENT_IMPORT as the status flag is mostly
    # used to decide if to call the cleanup
    $run_args->{ansible_present} = $self->{ansible_present} = 1;
    # skip ansible deployment in case of reusing infrastructure
    unless (get_var('QESAP_DEPLOYMENT_IMPORT')) {
        my @ret = qesap_execute(cmd => 'ansible', timeout => 3600, verbose => 1);
        if ($ret[0]) {
            if (check_var('IS_MAINTENANCE', '1')) {
                die("TEAM-9068 Ansible failed. Retry not supported for IBSM updates\n ret[0]: $ret[0]");
            }
            # Retry to deploy terraform + ansible
            if (qesap_terrafom_ansible_deploy_retry(error_log => $ret[1])) {
                die "Retry failed, original ansible return: $ret[0]";
            }

            # Recreate instances data as the redeployment of terraform + ansible changes the instances
            my $provider_instance = $self->provider_factory();
            my $instances = create_instance_data(provider => $provider_instance);
            foreach my $instance (@$instances) {
                record_info 'New Instance', join(' ', 'IP: ', $instance->public_ip, 'Name: ', $instance->instance_id);
                if (get_var('FENCING_MECHANISM') eq 'native' && $provider eq 'AZURE') {
                    qesap_az_setup_native_fencing_permissions(
                        vm_name => $instance->instance_id,
                        resource_group => qesap_az_get_resource_group());
                }
            }
            $self->{instances} = $run_args->{instances} = $instances;
            $self->{instance} = $run_args->{my_instance} = $run_args->{instances}[0];
            $self->{provider} = $run_args->{my_provider} = $provider_instance;    # Required for cleanup
        }
        record_info('FINISHED', 'Ansible deployment process finished successfully.');
    }

    # export instance data and disable cleanup
    if (get_var('QESAP_DEPLOYMENT_EXPORT')) {
        qesap_export_instances();
        record_info('CLEANUP OFF', "'QESAP_DEPLOYMENT_EXPORT' enabled, turning cleanup functions off.");
        set_var('QESAP_NO_CLEANUP', '1');
        set_var('QESAP_NO_CLEANUP_ON_FAILURE', '1');
    }


    get_var('QESAP_DEPLOYMENT_IMPORT')
      ? record_info('IMPORT OK', 'Importing infrastructure successfully.')
      : record_info('DEPLOY OK', 'Ansible deployment process finished successfully.');
}

sub post_run_hook {
    my ($self) = shift;
    qesap_cluster_logs();
    $self->SUPER::post_run_hook;
}

1;
