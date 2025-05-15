# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use sles4sap::qesap::qesapdeployment;
use sles4sap::qesap::qesap_aws;
use hacluster qw($crm_mon_cmd cluster_status_matches_regex);

sub run {
    my ($self) = @_;
    my $provider_setting = get_required_var('PUBLIC_CLOUD_PROVIDER');

    if (($provider_setting eq 'AZURE' && get_var('QESAPDEPLOY_IBSM_VNET') && get_var('QESAPDEPLOY_IBSM_RG')) ||
        ($provider_setting eq 'EC2' && get_var('QESAPDEPLOY_IBSM_PRJ_TAG')) ||
        ($provider_setting eq 'GCE' && get_var('QESAPDEPLOY_IBSM_VPC_NAME') && get_var('QESAPDEPLOY_IBSM_SUBNET_NAME') && get_var('QESAPDEPLOY_IBSM_SUBNET_REGION'))) {
        my @remote_cmd = (
            'ping -c3 ' . get_required_var('QESAPDEPLOY_DOWNLOAD_HOSTNAME'),
            'zypper -n ref -s -f',
            'zypper -n lr');
        qesap_ansible_cmd(cmd => $_, provider => $provider_setting, timeout => 300) for @remote_cmd;
    }
}

sub post_fail_hook {
    my ($self) = shift;
    # This test module does not have the fatal flag.
    # In case of failure, the next test_ module is executed too.
    # Deployment destroy is delegated to the destroy test module
    $self->SUPER::post_fail_hook;
}

1;
