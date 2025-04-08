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

    if ($provider_setting eq 'AZURE') {
        if (get_var('QESAPDEPLOY_IBSM_VNET') && get_var('QESAPDEPLOY_IBSM_RG')) {
            my @remote_cmd = (
                'ping -c3 ' . get_required_var('QESAPDEPLOY_DOWNLOAD_HOSTNAME'),
                'zypper -n ref -s -f',
                'zypper -n lr');
            qesap_ansible_cmd(cmd => $_, provider => $provider_setting, timeout => 300) for @remote_cmd;
        }
    }
    elsif ($provider_setting eq 'EC2') {
        if (get_var("QESAPDEPLOY_IBSMIRROR_IP_RANGE")) {
            my $deployment_name = qesap_calculate_deployment_name('qesapval');
            my $vpc_id = qesap_aws_get_vpc_id(resource_group => $deployment_name);
            die "No vpc_id in this deployment" if $vpc_id eq 'None';
            my $ibs_mirror_target_ip = get_var('QESAPDEPLOY_IBSMIRROR_IP_RANGE');    # '10.254.254.240/28'
            die 'Error in network peering setup.' if !qesap_aws_vnet_peering(target_ip => $ibs_mirror_target_ip, vpc_id => $vpc_id, mirror_tag => get_var('QESAPDEPLOY_IBSM_PRJ_TAG', 'IBS Mirror'));
            qesap_add_server_to_hosts(name => 'download.suse.de', ip => get_required_var("QESAPDEPLOY_IBSMIRROR_IP"));
            die 'Error in network peering delete.' if !qesap_aws_delete_transit_gateway_vpc_attachment(name => $deployment_name . '*');
        }
    }
}

sub post_fail_hook {
    my ($self) = shift;
    # This test module does not have both
    # fatal flag and qesap_test_postfail, so that in case of failure
    # the next test_ module is executed too.
    # Deployment destroy is delegated to the destroy test module
    $self->SUPER::post_fail_hook;
}

1;
