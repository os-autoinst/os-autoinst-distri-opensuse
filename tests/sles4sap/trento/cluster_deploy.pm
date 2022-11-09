# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deploy SAP Landscape using qe-sap-deployment and network peering with Trento server
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use qesapdeployment qw(qesap_upload_logs qesap_get_inventory qesap_ansible_cmd);
use trento;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    deploy_qesap();

    my $trento_rg = get_resource_group;
    my $cluster_rg = get_qesap_resource_group();
    my $cmd = join(' ',
        '/root/test/00.050-trento_net_peering_tserver-sap_group.sh',
        '-s', $trento_rg,
        '-n', get_vnet($trento_rg),
        '-t', $cluster_rg,
        '-a', get_vnet($cluster_rg));
    record_info('NET PEERING');
    assert_script_run($cmd, 360);

    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');

    qesap_ansible_cmd(cmd => 'crm status', provider => $prov, filter => $_), for ('vmhana01', 'vmhana02');
}

sub post_fail_hook {
    my ($self) = shift;
    select_serial_terminal;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support('cluster_deploy');
        az_delete_group();
    }
    destroy_qesap();
    $self->SUPER::post_fail_hook;
}

1;
