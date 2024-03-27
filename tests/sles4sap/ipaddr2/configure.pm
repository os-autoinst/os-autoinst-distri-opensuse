# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create a VM with a single NIC and 3 ip-config
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';

use constant DEPLOY_PREFIX => 'ip2t';

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    my $rg = DEPLOY_PREFIX . get_current_job_id();
    my $os_ver = get_required_var('CLUSTER_OS_VER');

    select_serial_terminal;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $rg = DEPLOY_PREFIX . get_current_job_id();
    script_run("az group delete --name $rg -y", timeout => 600);
    $self->SUPER::post_fail_hook;
}

1;
