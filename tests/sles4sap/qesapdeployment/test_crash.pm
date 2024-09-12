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

    # Not test so much for the moment,
    # just that crash trough Ansible does not hang Ansible execution
    qesap_ansible_cmd(
        cmd => 'sudo echo b > /proc/sysrq-trigger &',
        provider => $provider_setting,
        filter => '"hana[0]"',
        timeout => 300);
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_test_postfail(
        provider => get_required_var('PUBLIC_CLOUD_PROVIDER'),
        net_peering_is => get_var("QESAPDEPLOY_IBSMIRROR_RESOURCE_GROUP", get_var("QESAPDEPLOY_IBSMIRROR_IP_RANGE")));
    $self->SUPER::post_fail_hook;
}

1;
