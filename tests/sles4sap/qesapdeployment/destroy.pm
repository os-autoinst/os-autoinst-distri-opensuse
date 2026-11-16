# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Destroy the deployed infrastructure
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

qesapdeployment/destroy.pm - Destroy the deployed infrastructure

=head1 DESCRIPTION

Tear down the entire SAP HANA cluster environment created by
the qe-sap-deployment framework. It ensures that all
cloud resources are properly removed to avoid orphaned instances and
unnecessary costs.

It executes 'qesap.py' with the 'ansible -d' and 'terraform -d' commands
to reverse the deployment process. If the Ansible inventory is not
present, it skips 'ansible -d' and runs only 'terraform -d'.

The module has the 'always_run' flag: it runs also after a fatal failure
in a previous module. The non-fatal 'test_' modules do not destroy the
deployment in their post_fail_hook: this module does the destroy.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider, which is required for SSH intrusion detection
before teardown.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use sles4sap::qesap::qesapdeployment;
use sles4sap::publiccloud;
use sles4sap::qesap::aws;

sub run {
    select_serial_terminal;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');

    qesap_ssh_intrusion_detection(provider => $provider);

    # The inventory is missing if the deployment is already destroyed
    # (for example by the post_fail_hook of a fatal module) or if
    # Terraform failed before it created the inventory.
    # Ansible cannot run without the inventory: skip the de-register.
    # Terraform destroy must run in all cases.
    my @ansible_ret = (0);
    my $inventory = qesap_get_inventory(provider => $provider);
    if (script_run("test -e $inventory", 60)) {
        record_info('NO INVENTORY', "Inventory $inventory not found: skip 'qesap.py ansible -d'");
    }
    else {
        @ansible_ret = qesap_execute(
            cmd => 'ansible',
            cmd_options => '-d',
            logname => 'qesap_exec_ansible_destroy.log.txt',
            verbose => 1,
            timeout => 300);
        qesap_cluster_logs() if ($ansible_ret[0]);
    }
    my @terraform_ret = qesap_execute(
        cmd => 'terraform',
        cmd_options => '-d',
        logname => 'qesap_exec_terraform_destroy.log.txt',
        verbose => 1,
        timeout => 1800);
    die "'qesap.py ansible -d' return: $ansible_ret[0]" if ($ansible_ret[0]);
    die "'qesap.py terraform -d' return: $terraform_ret[0]" if ($terraform_ret[0]);
}

sub test_flags {
    # Run also after a fatal failure in a previous module,
    # to not leave cloud resources behind.
    return {always_run => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}

1;
