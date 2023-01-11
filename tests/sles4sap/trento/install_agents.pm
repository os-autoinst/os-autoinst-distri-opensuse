# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deploy SAP Landscape using qe-sap-deployment and network peering with Trento server
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use qesapdeployment 'qesap_upload_logs';
use trento;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $basedir = '/root/test';
    my $wd = '/root/work_dir';
    enter_cmd "mkdir $wd";

    my $agent_api_key = trento_api_key($wd, $basedir);

    cluster_install_agent($wd, $basedir, $agent_api_key);
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
        trento_support();
        trento_collect_scenarios('install_agent');
        az_delete_group();
    }
    cluster_destroy();
    $self->SUPER::post_fail_hook;
}

1;
