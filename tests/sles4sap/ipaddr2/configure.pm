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

    my $bastion_ip = ipaddr2_bastion_pubip();

    record_info("STAGE 1", "Prepare all the ssh connections within the 2 internal VMs");
    ipaddr2_bastion_key_accept(bastion_ip => $bastion_ip);
    ipaddr2_internal_key_accept(bastion_ip => $bastion_ip);
    ipaddr2_internal_key_gen(bastion_ip => $bastion_ip);

    # check basic stuff that has to work before to start
    #ipaddr2_os_connectivity_sanity(bastion_ip => $bastion_ip);
    record_info("STAGE 2", "Init and configure the Pacemaker cluster");
    ipaddr2_create_cluster(bastion_ip => $bastion_ip);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_destroy();
    $self->SUPER::post_fail_hook;
}

1;
