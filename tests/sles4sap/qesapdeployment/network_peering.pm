# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use mmapi 'get_current_job_id';
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub run {
    my ($self, $run_args) = @_;
    my $instance = $run_args->{my_instance};
    record_info("$instance");
    my $rg = qesap_get_az_resource_group();
    my $target_rg = get_required_var('QESAP_TARGET_RESOURCE_GROUP');
    qesap_az_vnet_peering(source_group => $rg, target_group => $target_rg);
    add_server_to_hosts();
}

sub test_flags {
    return {fatal => 1};
}

sub add_server_to_hosts {
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $ibsm_ip = get_required_var("IBSM_IP");
    qesap_ansible_cmd(cmd => "sed -i '\\\$a $ibsm_ip download.suse.de' /etc/hosts",
        provider => $prov,
        host_keys_check => 1);
    qesap_ansible_cmd(cmd => "cat /etc/hosts",
        provider => $prov);
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300) unless (script_run("test -e $inventory"));
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
