# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create a VM with a single NIC and 3 ip-config
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::qesap::qesapdeployment qw (qesap_az_vnet_peering_delete);
use sles4sap::ipaddr2 qw(
  ipaddr2_bastion_key_accept
  ipaddr2_bastion_pubip
  ipaddr2_configure_web_server
  ipaddr2_cluster_create
  ipaddr2_deployment_logs
  ipaddr2_infra_destroy
  ipaddr2_internal_key_accept
  ipaddr2_internal_key_gen
  ipaddr2_cloudinit_logs
  ipaddr2_scc_check
  ipaddr2_scc_register
  ipaddr2_refresh_repo
  ipaddr2_azure_resource_group
);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    record_info("TEST STAGE", "Prepare all the ssh connections within the 2 internal VMs");
    my $bastion_ip = ipaddr2_bastion_pubip();
    ipaddr2_bastion_key_accept(bastion_ip => $bastion_ip);

    my %int_key_args = (bastion_ip => $bastion_ip);
    # unsupported option "accept-new" for default ssh used in 12sp5
    $int_key_args{key_checking} = 'no' if (check_var('IPADDR2_KEYCHECK_OLD', '1'));
    ipaddr2_internal_key_accept(%int_key_args);

    # default for ipaddr2_internal_key_gen is cloudadmin
    $int_key_args{user} = 'root' unless check_var('IPADDR2_ROOTLESS', '1');
    ipaddr2_internal_key_gen(%int_key_args);

    # Check if cloudinit is active or not. In case it is,
    # registration was eventually there and no need to per performed here.
    if (check_var('IPADDR2_CLOUDINIT', 0)) {
        # Check if reg code is provided or not, PAYG does not need it
        if (get_var('SCC_REGCODE_SLES4SAP')) {
            # Registration was not part of cloud-init but still needed
            record_info("TEST STAGE", "Registration");
            foreach (1 .. 2) {
                # Check if somehow the image is already registered or not
                my $is_registered = ipaddr2_scc_check(
                    bastion_ip => $bastion_ip,
                    id => $_);
                record_info('is_registered', "$is_registered");
                # Only perform registration if it is no
                # So test can be programmatically configured not to perform
                # any registration, by not providing SCC_REGCODE_SLES4SAP variable.
                # But even if it is, registration is only performed if image
                # at this test moment is not registered.
                ipaddr2_scc_register(
                    bastion_ip => $bastion_ip,
                    id => $_,
                    scc_code => get_required_var('SCC_REGCODE_SLES4SAP')) if ($is_registered ne 1);
            }
        }
        record_info("TEST STAGE", "Install the web server");
        my %web_install_args;
        $web_install_args{external_repo} = get_var('IPADDR2_NGINX_EXTREPO') if get_var('IPADDR2_NGINX_EXTREPO');
        $web_install_args{bastion_ip} = $bastion_ip;
        foreach (1 .. 2) {
            $web_install_args{id} = $_;
            ipaddr2_configure_web_server(%web_install_args);
        }
    } else {
        # Registartion eventually performed at first boot by cloud-init script.
        # Just a repo sync is needed now.
        foreach (1 .. 2) {
            ipaddr2_refresh_repo(
                bastion_ip => $bastion_ip,
                id => $_);
        }
    }
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_cloudinit_logs() unless check_var('IPADDR2_CLOUDINIT', 0);
    if (my $ibsm_rg = get_var('IBSM_RG')) {
        qesap_az_vnet_peering_delete(source_group => ipaddr2_azure_resource_group(), target_group => $ibsm_rg);
    }
    ipaddr2_infra_destroy();
    $self->SUPER::post_fail_hook;
}

1;
