# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create a VM with a single NIC and 3 ip-config
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::ipaddr2 qw(
  ipaddr2_infra_deploy
  ipaddr2_deployment_logs
  ipaddr2_deployment_sanity
  ipaddr2_infra_destroy
  ipaddr2_cloudinit_logs
);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    # Init all the PC gears (ssh keys, CSP credentials)
    my $provider = $self->provider_factory();
    # remove configuration file created by the PC factory
    # as it interfere with ssh behavior.
    # in particular it has setting about verbosity that
    # break test steps that relay to remote ssh comman output
    assert_script_run('rm ~/.ssh/config');

    my %deployment = (
        region => $provider->provider_client->region,
        os => get_required_var('CLUSTER_OS_VER'),
        diagnostic => get_var('IPADDR2_DIAGNOSTIC', 0),
        cloudinit => get_var('IPADDR2_CLOUDINIT', 1));
    $deployment{scc_code} = get_var('SCC_REGCODE_SLES4SAP') if (get_var('SCC_REGCODE_SLES4SAP'));
    $deployment{trusted_launch} = 0 if (check_var('IPADDR2_TRUSTEDLAUNCH', 0));
    ipaddr2_infra_deploy(%deployment);

    ipaddr2_deployment_sanity();
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_cloudinit_logs() unless check_var('IPADDR2_CLOUDINIT', 0);
    ipaddr2_infra_destroy();
    $self->SUPER::post_fail_hook;
}

1;
