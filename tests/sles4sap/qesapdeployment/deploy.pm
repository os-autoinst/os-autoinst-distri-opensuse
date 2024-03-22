# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub run {
    my ($self) = @_;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my @ret = qesap_execute_conditional_retry(cmd => 'terraform', verbose => 1, timeout => 1800, retries => 1, error_string => 'An internal execution error occurred. Please retry later');

    my $inventory = qesap_get_inventory(provider => $provider);
    upload_logs($inventory, failok => 1);

    # Set up azure native fencing
    if (get_var('QESAPDEPLOY_FENCING') eq 'native' && $provider eq 'AZURE') {
        my @nodes = qesap_get_nodes_names(provider => $provider);
        foreach my $host_name (@nodes) {
            if ($host_name =~ /hana/) {
                qesap_az_setup_native_fencing_permissions(
                    vm_name => $host_name,
                    resource_group => qesap_az_get_resource_group());
            }
        }
    }

    my @remote_ips = qesap_remote_hana_public_ips;
    record_info 'Remote IPs', join(' - ', @remote_ips);
    foreach my $host (@remote_ips) {
        die 'Timed out while waiting for ssh to be available in the CSP instances' if qesap_wait_for_ssh(host => $host) == -1;
    }
    @ret = qesap_execute(cmd => 'ansible', cmd_options => '--profile', verbose => 1, timeout => 3600);
    if ($ret[0]) {
        # Retry to deploy terraform + ansible
        if (qesap_terrafom_ansible_deploy_retry(error_log => $ret[1])) {
            die "Retry failed, original ansible return: $ret[0]";
        }
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_cluster_logs();
    qesap_upload_logs();
    my $inventory = qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300) unless (script_run("test -e $inventory"));
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = shift;
    qesap_cluster_logs();
    $self->SUPER::post_run_hook;
}

1;
