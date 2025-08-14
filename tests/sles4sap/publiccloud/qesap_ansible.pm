# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Execute ansible deployment using qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

use base 'sles4sap_publiccloud_basetest';
use testapi;
use publiccloud::utils;
use sles4sap_publiccloud;
use sles4sap::qesap::qesapdeployment;
use serial_terminal 'select_serial_terminal';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');

    # Needed to have ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    my $ha_enabled = get_required_var('HA_CLUSTER') =~ /false|0/i ? 0 : 1;
    select_serial_terminal;

    # Record packages list before deploying ansible if needed
    if (get_var('SAVE_LIST_OF_PACKAGES')) {
        my $in = $self->{instances}->[0];
        $in->ssh_script_run(cmd => 'rpm -qa > /tmp/rpm-qa-before-patch-system.txt');
        $in->upload_log('/tmp/rpm-qa-before-patch-system.txt');
    }

    # mark as done in advance and also in case of
    # QESAP_DEPLOYMENT_IMPORT as the status flag is mostly
    # used to decide if to call the cleanup
    $run_args->{ansible_present} = $self->{ansible_present} = 1;
    # skip ansible deployment in case of reusing infrastructure
    unless (get_var('QESAP_DEPLOYMENT_IMPORT')) {
        my @ret = qesap_execute(
            cmd => 'ansible',
            cmd_options => join(' ', '--profile', '--junit', '/tmp/results/'),
            logname => 'qesap_exec_ansible.log.txt',
            timeout => 3600,
            verbose => 1);
        my $find_cmd = join(' ',
            'find',
            '/tmp/results/',
            '-type', 'f',
            '-iname', "*.xml");
        my $ansible_output = script_output("cat $ret[1]");
        my $reference;
        my $desc_known_issue;

        foreach my $ansible_line (split /\n/, $ansible_output) {
            chomp $ansible_line;
            if ($ansible_line =~ qr/\[OSADO\]\[softfail\] ([a-zA-Z]+#\S+) (.*)/) {
                $reference = $1;
                $desc_known_issue = $2;
                record_soft_failure("$reference - $desc_known_issue");
            }
        }
        for my $log (split(/\n/, script_output($find_cmd))) {
            parse_extra_log("XUnit", $log);
        }
        if ($ret[0]) {
            if (check_var('IS_MAINTENANCE', '1')) {
                die("TEAM-9068 Ansible failed. Retry not supported for IBSM updates\n ret[0]: $ret[0]");
            }
            # Retry to deploy terraform + ansible
            if (qesap_terrafom_ansible_deploy_retry(error_log => $ret[1], provider => $provider)) {
                die "Retry failed, original ansible return: $ret[0]";
            }

            # Recreate instances data as the redeployment of terraform + ansible changes the instances
            my $provider_instance = $self->provider_factory();
            my $instances = create_instance_data(provider => $provider_instance);
            foreach my $instance (@$instances) {
                record_info 'New Instance', join(' ', 'IP: ', $instance->public_ip, 'Name: ', $instance->instance_id);
                if (get_var('FENCING_MECHANISM') eq 'native' && is_azure && check_var('AZURE_FENCE_AGENT_CONFIGURATION', 'msi')) {
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
