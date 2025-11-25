# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use sles4sap::qesap::qesapdeployment;
use sles4sap::qesap::azure;

sub run {
    my ($self) = @_;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my %qesap_exec_args_terraform = (
        cmd => 'terraform',
        logname => 'qesap_exec_terraform.log.txt',
        verbose => 1,
        timeout => 1800);
    $qesap_exec_args_terraform{cmd_options} = '--parallel ' . get_var('QESAPDEPLOY_TERRAFORM_PARALLEL') if get_var('QESAPDEPLOY_TERRAFORM_PARALLEL');

    my @ret = qesap_execute(%qesap_exec_args_terraform);
    die "Retry failed, original ansible return: $ret[0]" if ($ret[0]);

    my $inventory = qesap_get_inventory(provider => $provider);
    upload_logs($inventory, failok => 1);

    # Set up azure native fencing for MSI
    if (get_var('QESAPDEPLOY_FENCING') eq 'native' && $provider eq 'AZURE' && check_var('QESAPDEPLOY_AZURE_FENCE_AGENT_CONFIGURATION', 'msi')) {
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
    @ret = qesap_execute(
        cmd => 'ansible',
        cmd_options => join(' ', '--profile', '--junit', '/tmp/results/'),
        logname => 'qesap_exec_ansible.log.txt',
        verbose => 1,
        timeout => 3600);
    record_info('ANSIBLE RESULT', "ret0:$ret[0] ret1:$ret[1]");
    my $find_cmd = join(' ',
        'find',
        '/tmp/results/',
        '-type', 'f',
        '-iname', "*.xml");
    for my $log (split(/\n/, script_output($find_cmd))) {
        parse_extra_log("XUnit", $log);
        enter_cmd("rm $log");
    }
    if ($ret[0]) {
        record_info("Retry to deploy terraform + ansible");
        die "Retry failed, original ansible return: $ret[0]"
          if (qesap_terraform_ansible_deploy_retry(error_log => $ret[1], provider => $provider));
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
    qesap_execute(
        cmd => 'ansible',
        cmd_options => '-d',
        logname => 'qesap_exec_ansible_destroy.log.txt',
        verbose => 1,
        timeout => 300) unless (script_run("test -e $inventory"));
    qesap_execute(
        cmd => 'terraform',
        cmd_options => '-d',
        logname => 'qesap_exec_terraform_destroy.log.txt',
        verbose => 1,
        timeout => 1200);
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = shift;
    qesap_cluster_logs();
    $self->SUPER::post_run_hook;
}

1;
