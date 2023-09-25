# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use base 'sles4sap_publiccloud_basetest';
use testapi;
use qesapdeployment;
use publiccloud::utils qw(is_azure is_ec2);

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    die 'Network peering already in place' if ($self->{network_peering_present});
    my $ibs_mirror_resource_group = get_required_var('IBSM_RG');
    if (is_azure) {
        my $rg = qesap_az_get_resource_group();
        qesap_az_vnet_peering(source_group => $rg, target_group => $ibs_mirror_resource_group);
    } elsif (is_ec2) {
        my $vpc_id = qesap_aws_get_vpc_id(resource_group => $self->deployment_name() . '*');
        my $ibs_mirror_target_ip = get_required_var('IBSM_IPRANGE');    # '10.254.254.240/28'
        die 'Error in network peering setup.' if !qesap_aws_vnet_peering(target_ip => $ibs_mirror_target_ip, vpc_id => $vpc_id);
    }
    $run_args->{network_peering_present} = $self->{network_peering_present} = 1;
}

1;
