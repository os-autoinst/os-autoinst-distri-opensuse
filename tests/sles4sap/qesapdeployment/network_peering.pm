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
    my $rg = qesap_az_get_resource_group();
    my $target_rg = get_required_var('QESAP_TARGET_RESOURCE_GROUP');
    qesap_az_vnet_peering(source_group => $rg, target_group => $target_rg);
    qesap_add_server_to_hosts(name => 'download.suse.de', ip => get_required_var("IBSM_IP"));
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();

    # destroy the network peering, if it was created
    my $rg = qesap_az_get_resource_group();
    my $vn = qesap_az_get_vnet($rg);
    my $target_rg = get_required_var('QESAP_TARGET_RESOURCE_GROUP');
    my $target_vn = qesap_az_get_vnet($target_rg);
    qesap_az_vnet_peering_delete(source_group => $rg, source_vnet => $vn, target_group => $target_rg, target_vnet => $target_vn);

    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300) unless (script_run("test -e $inventory"));
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
