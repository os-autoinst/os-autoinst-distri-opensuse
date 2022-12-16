# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deploy SAP Landscape using qe-sap-deployment and network peering with Trento server
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use qesapdeployment qw(qesap_upload_logs qesap_ansible_cmd);
use trento;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    cluster_deploy();
    cluster_trento_net_peering('/root/test');

    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $primary_host = 'vmhana01';
    qesap_ansible_cmd(cmd => 'crm cluster wait_for_startup', provider => $prov, filter => $primary_host);

    cluster_print_cluster_status($primary_host);
}

sub test_flags {
    return {fatal => 1};
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
    cluster_destroy();
    $self->SUPER::post_fail_hook;
}

1;
