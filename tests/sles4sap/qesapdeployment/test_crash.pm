# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use sles4sap::qesap::qesapdeployment;

sub run {
    my ($self) = @_;
    my $provider_setting = get_required_var('PUBLIC_CLOUD_PROVIDER');

    # Not test so much for the moment,
    # just that crash trough Ansible does not hang Ansible execution
    qesap_ansible_cmd(
        cmd => 'sudo echo b > /proc/sysrq-trigger &',
        provider => $provider_setting,
        filter => '"hana[0]"',
        timeout => 300);

    # Check that if comes back to life
    qesap_ansible_cmd(
        cmd => 'echo \"I am back\"',
        provider => $provider_setting,
        filter => '"hana[0]"',
        timeout => 300);

    qesap_ansible_cmd(
        cmd => 'sudo systemctl is-system-running',
        provider => $provider_setting,
        filter => '"hana[0]"',
        timeout => 300);
}

sub post_fail_hook {
    my ($self) = shift;
    # This test module does not have the fatal flag.
    # In case of failure, the next test_ module is executed too.
    # Deployment destroy is delegated to the destroy test module
    $self->SUPER::post_fail_hook;
}

1;
