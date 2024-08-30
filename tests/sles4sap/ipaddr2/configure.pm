# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create a VM with a single NIC and 3 ip-config
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use sles4sap::ipaddr2;

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    record_info("TEST STAGE", "Prepare all the ssh connections within the 2 internal VMs");
    my $bastion_ip = ipaddr2_bastion_pubip();
    ipaddr2_bastion_key_accept(bastion_ip => $bastion_ip);
    ipaddr2_internal_key_accept(bastion_ip => $bastion_ip);
    ipaddr2_internal_key_gen(bastion_ip => $bastion_ip);

    if (check_var('IPADDR2_CLOUDINIT', 0)) {
        if (get_var('SCC_REGCODE_SLES4SAP')) {
            # Register was not part of cloud-init
            record_info("TEST STAGE", "Register");
            foreach (1 .. 2) {
                my $is_registered = ipaddr2_registeration_check(
                    bastion_ip => $bastion_ip,
                    id => $_);
                record_info('is_registered', "$is_registered");
                ipaddr2_registeration_set(
                    bastion_ip => $bastion_ip,
                    id => $_,
                    scc_code => get_required_var('SCC_REGCODE_SLES4SAP')) if ($is_registered ne 1);
            }
        }
        record_info("TEST STAGE", "Install the web server");
        foreach (1 .. 2) {
            ipaddr2_configure_web_server(bastion_ip => $bastion_ip, id => $_);
        }
    }

    record_info("TEST STAGE", "Init and configure the Pacemaker cluster");
    ipaddr2_create_cluster(bastion_ip => $bastion_ip);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_os_cloud_init_logs() unless check_var('IPADDR2_CLOUDINIT', 0);
    ipaddr2_destroy();
    $self->SUPER::post_fail_hook;
}

1;
