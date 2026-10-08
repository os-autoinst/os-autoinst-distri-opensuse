# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: destroy the cloud deployment
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

cloud_zypper_patch/destroy.pm - Destroy the cloud deployment

=head1 DESCRIPTION

This module is responsible for cleaning up and destroying all the Azure
resources created for the cloud_zypper_patch test.

Its main tasks are:

- If a network peering was established with an IBSm (Infrastructure Build and
  Support mirror) environment, it deletes the peering connection.
- It destroys the entire Azure Resource Group, which contains the VM and other
  resources created by the C<deploy.pm> module.

This module is typically the last one to run in the test suite.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm (Infrastructure Build and
Support mirror) environment. This is required to clean up the network peering.

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

    zp_azure_destroy(ibsm_rg => get_required_var('IBSM_RG'));
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    zp_azure_destroy(ibsm_rg => get_required_var('IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
