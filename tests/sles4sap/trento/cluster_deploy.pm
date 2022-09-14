# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Setup and install more tools in the running jumphost image for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use base 'trento';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    $self->trento_qesap_deploy();
    my $cluster_rg = $self->get_qesap_resource_group();
    my $cmd = '/root/test/00.050-trento_net_peering_tserver-sap_group.sh' .
      ' -s ' . $self->get_resource_group .
      ' -n $(az network vnet list -g ' . $self->get_resource_group . ' --query "[0].name" -o tsv)' .
      " -t $cluster_rg" .
      ' -a $(az network vnet list -g ' . $cluster_rg . ' --query "[0].name" -o tsv)';
    record_info('NET PEERING');
    assert_script_run($cmd, 360);

    my $wd = '/root/work_dir';
    enter_cmd "mkdir $wd";
    $cmd = '/root/test/trento-server-api-key.sh' .
      ' -u admin' .
      ' -p ' . $self->get_trento_password() .
      ' -i ' . $self->get_trento_ip() .
      " -d $wd";
    my $agent_api_key = script_output($cmd);

    my $package = 'trento-agent-1.1.0+git.dev19.1660743644.2b7a773-150300.5.1.x86_64.rpm';
    $cmd = "curl \"https://dist.suse.de/ibs/Devel:/SAP:/trento:/factory/SLE_15_SP3/x86_64/$package\"" .
      "  --output $wd/$package";
    assert_script_run($cmd);

    my $inventory = '/root/qe-sap-deployment/terraform/azure/inventory.yaml';
    $cmd = 'ansible-playbook -vv' .
      " -i $inventory" .
      ' /root/test/trento-agent.yaml' .
      " -e agent_rpm=$wd/$package" .
      " -e api_key=$agent_api_key" .
      " -e trento_private_addr=10.0.0.4";
    assert_script_run($cmd);
}

sub post_fail_hook {
    my ($self) = shift;
    $self->select_serial_terminal;
    $self->SUPER::post_fail_hook;
}

1;
