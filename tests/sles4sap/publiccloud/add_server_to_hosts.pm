# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub run {
    my ($self, $run_args) = @_;
    my $instance = $run_args->{my_instance};
    record_info("$instance");

    my $ibsm_ip = get_required_var('IBSM_IP');
    $instance->run_ssh_command(cmd => "echo \"$ibsm_ip download.suse.de\" | sudo tee -a /etc/hosts", username => 'cloudadmin');
    $instance->run_ssh_command(cmd => 'cat /etc/hosts', username => 'cloudadmin');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();

    # destroy the network peering, if it was created
    qesap_az_vnet_peering_delete(source_group => qesap_az_get_resource_group(),
        target_group => get_required_var('IBSM_RG'));

    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300) unless (script_run("test -e $inventory"));
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
