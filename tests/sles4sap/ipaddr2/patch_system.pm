# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Confi
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use qesapdeployment qw( qesap_az_vnet_peering qesap_az_vnet_peering_delete );
use utils qw(ssh_fully_patch_system);
use sles4sap::ipaddr2 qw(
  ipaddr2_azure_resource_group
  ipaddr2_bastion_pubip
  ipaddr2_ssh_internal
  ipaddr2_clean_network_peering
  ipaddr2_bastion_ssh_addr
  ipaddr2_get_internal_vm_private_ip
);

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # Create network peering
    my $rg = ipaddr2_azure_resource_group();
    my $ibs_mirror_resource_group = get_required_var('IBSM_RG');
    qesap_az_vnet_peering(source_group => $rg, target_group => $ibs_mirror_resource_group);

    # Set IPADDR2_NETWORK_PEERING to 1 for post_fail_hook and cleanup work
    set_var('IPADDR2_NETWORK_PEERING', 1);

    # Add server to hosts
    my $ibsm_ip = get_required_var('IBSM_IP');
    my $bastion_pubip = ipaddr2_bastion_pubip();
    foreach my $id (1 .. 2) {
        ipaddr2_ssh_internal(id => $id,
            cmd => "echo \"$ibsm_ip download.suse.de\" | sudo tee -a /etc/hosts",
            bastion_ip => $bastion_pubip);
    }

    # Add repos
    my $count = 0;
    my @repos = split(/,/, get_var('INCIDENT_REPO', ''));
    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        if ($maintrepo =~ /Development-Tools/ or $maintrepo =~ /Desktop-Applications/) {
            record_info("MISSING REPOS", "There are repos in this incident, that are not uploaded to IBSM. ($maintrepo). Later errors, if they occur, may be due to these.");
            next;
        }
        my $zypper_cmd = "sudo zypper --no-gpg-checks ar -f -n TEST_$count";
        $zypper_cmd = $zypper_cmd . " --priority " . get_var('REPO_PRIORITY') if get_var('REPO_PRIORITY');
        $zypper_cmd = $zypper_cmd . " $maintrepo TEST_$count";

        foreach my $id (1 .. 2) {
            ipaddr2_ssh_internal(id => $id,
                cmd => $zypper_cmd,
                bastion_ip => $bastion_pubip);
        }
        $count++;
    }

    foreach my $id (1 .. 2) {
        ipaddr2_ssh_internal(id => $id,
            cmd => "sudo zypper -n ref",
            bastion_ip => $bastion_pubip,
            timeout => 1500);
    }

    # zypper patch
    my $host_ip = ipaddr2_bastion_ssh_addr(bastion_ip => $bastion_pubip);
    foreach my $id (1 .. 2) {
        my $vm_ip = ipaddr2_get_internal_vm_private_ip(id => $id);
        my $remote = "-J $host_ip cloudadmin@" . "$vm_ip";
        ssh_fully_patch_system($remote);
    }
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_cloudinit_logs() unless check_var('IPADDR2_CLOUDINIT', 0);
    ipaddr2_clean_network_peering if check_var('IPADDR2_NETWORK_PEERING', 1);
    ipaddr2_infra_destroy();
    $self->SUPER::post_fail_hook;
}

1;
