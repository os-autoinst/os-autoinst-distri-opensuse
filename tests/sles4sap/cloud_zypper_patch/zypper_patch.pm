# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: perform a zypper patch on the SUT
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use sles4sap::cloud_zypper_patch;
use testapi;
use serial_terminal 'select_serial_terminal';


sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    zp_zypper_patch();
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    zp_azure_destroy(target_rg => get_required_var('ZP_IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
