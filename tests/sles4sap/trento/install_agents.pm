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
use trento qw(destroy_qesap get_trento_ip get_trento_password az_delete_group install_agent k8s_logs trento_support);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $wd = '/root/work_dir';
    enter_cmd "mkdir $wd";
    my $cmd = join(' ', '/root/test/trento-server-api-key.sh',
        '-u', 'admin',
        '-p', get_trento_password(),
        '-i', get_trento_ip(),
        '-d', $wd, '-v');
    my $agent_api_key;
    my @lines = split(/\n/, script_output($cmd));
    foreach my $line (@lines) {
        if ($line =~ /api_key:(.*)/) {
            $agent_api_key = $1;
        }
    }

    $cmd = install_agent($wd, '/root/test', $agent_api_key);
}

sub post_fail_hook {
    my ($self) = shift;
    select_serial_terminal;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support('install_agent');
        az_delete_group();
    }
    destroy_qesap();
    $self->SUPER::post_fail_hook;
}

1;
