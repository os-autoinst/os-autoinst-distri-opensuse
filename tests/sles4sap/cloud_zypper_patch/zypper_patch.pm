# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: perform a zypper patch on the SUT
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

cloud_zypper_patch/zypper_patch.pm - Perform a zypper patch on the SUT

=head1 DESCRIPTION

This module applies all available patches to the SUT (System Under Test) using
the `zypper patch` command. This ensures that the system is up-to-date before
any further tests are performed.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm (Infrastructure Build and
Support mirror) environment. This is used in the C<post_fail_hook> to clean up
the network peering on failure.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use sles4sap::cloud_zypper_patch;

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
    zp_azure_destroy(ibsm_rg => get_required_var('IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
