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
use base 'trento';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $wd = '/root/work_dir';
    enter_cmd "mkdir $wd";
    my $cmd = '/root/test/trento-server-api-key.sh' .
      ' -u admin' .
      ' -p ' . $self->get_trento_password() .
      ' -i ' . $self->get_trento_ip() .
      " -d $wd -v";
    my $agent_api_key;
    my @lines = split(/\n/, script_output($cmd));
    foreach my $line (@lines) {
        if ($line =~ /api_key:(.*)/) {
            $agent_api_key = $1;
        }
    }

    $cmd = $self->install_agent($wd, '/root/test', $agent_api_key, '10.0.0.4');
}

sub post_fail_hook {
    my ($self) = shift;
    select_serial_terminal;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        trento::k8s_logs(qw(web runner));
        $self->az_delete_group;
    }
    $self->destroy_qesap();
    $self->SUPER::post_fail_hook;
}

1;
