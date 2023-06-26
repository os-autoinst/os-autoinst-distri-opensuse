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
use publiccloud::utils qw(is_azure is_ec2);

sub run {
    my ($self, $run_args) = @_;
    my $instance = $run_args->{my_instance};
    record_info("$instance");
    my $ibs_mirror_resource_group = get_required_var('IBSM_RG');
    if (is_azure) {
        my $rg = qesap_az_get_resource_group();
        qesap_az_vnet_peering(source_group => $rg, target_group => $ibs_mirror_resource_group);
    } elsif (is_ec2) {
        my $deployment_name = qesap_calculate_deployment_name(get_var('PUBLIC_CLOUD_RESOURCE_GROUP', 'qesaposd'));
        my $vpc_id = qesap_aws_get_vpc_id(resource_group => $deployment_name . '*');
        my $ibs_mirror_target_ip = get_var('IBSM_IPRANGE');    # '10.254.254.240/28'
        die 'Error in network peering setup.' if !qesap_aws_vnet_peering(target_ip => $ibs_mirror_target_ip, vpc_id => $vpc_id);
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();

    if (is_azure) {
        # destroy the network peering, if it was created
        qesap_az_vnet_peering_delete(source_group => qesap_az_get_resource_group(),
                                     target_group => get_required_var('IBSM_RG'));
    } elsif (is_ec2) {
        my $deployment_name = qesap_calculate_deployment_name();
        qesap_aws_delete_transit_gateway_vpc_attachment(name => $deployment_name . '*');
    }

    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300) unless (script_run("test -e $inventory"));
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
