# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;
use hacluster qw($crm_mon_cmd cluster_status_matches_regex);

sub run {
    my ($self) = @_;
    my $provider_setting = get_required_var('PUBLIC_CLOUD_PROVIDER');

    qesap_ansible_cmd(cmd => 'ls -lai /hana/', provider => $provider_setting, filter => 'hana');
    my $crm_status = qesap_ansible_script_output(
        cmd => 'crm status',
        provider => $provider_setting,
        host => '"hana[0]"',
        root => 1
    );
    record_info("crm status", $crm_status);
    if ($provider_setting eq 'AZURE') {
        if (cluster_status_matches_regex($crm_status)) {
            record_info('Retry', 'Found issue, do crm resource cleanup and retry');
            qesap_ansible_cmd(cmd => 'sudo crm resource cleanup', provider => $provider_setting, filter => 'hana');
            qesap_ansible_cmd(cmd => 'cs_wait_for_idle --sleep 5', provider => $provider_setting, filter => 'hana');
            $crm_status = qesap_ansible_script_output(
                cmd => 'crm status',
                provider => $provider_setting,
                host => '"hana[0]"',
                root => 1
            );
            record_info('Retry crm status', $crm_status);
            die 'Cluster resources throwing errors' if cluster_status_matches_regex($crm_status);
        }
    }

    qesap_ansible_cmd(cmd => $crm_mon_cmd, provider => $provider_setting, filter => '"hana[0]"');
    qesap_cluster_logs();
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_test_postfail(
        provider => get_required_var('PUBLIC_CLOUD_PROVIDER'),
        net_peering_is => get_var("QESAPDEPLOY_IBSMIRROR_RESOURCE_GROUP", get_var("QESAPDEPLOY_IBSMIRROR_IP_RANGE")));
    $self->SUPER::post_fail_hook;
}

1;
