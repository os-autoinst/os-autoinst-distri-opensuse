# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run zypper patch and reboot
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/patch_system.pm - Apply system patches to the SUT for the ipaddr2 test

=head1 DESCRIPTION

This module performs a standard system update on both SUT (System Under Test)
virtual machines.

It executes `zypper patch` to install all available patches and then reboots
the systems to ensure that all updates, including any kernel updates, are
correctly applied and active. This step helps ensure the SUTs are in a
consistent and up-to-date state for subsequent tests.

=head1 SETTINGS

This module does not require any specific configuration variables for its core functionality.
Some variables are needed for the correct execution of the post_fail_hook

=over

=item B<IPADDR2_CLOUDINIT>

Enables or disables the use of cloud-init for SUT setup. Defaults to enabled (1).
When enabled, cloud-init handles tasks such as image registration,
installation of nginx and socat, and creation of a basic web page for SUT identification.

=item B<IPADDR2_DIAGNOSTIC>

Enable some diagnostic features as the additional deployment of some Azure resources needed
to collect boot logs.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSm (Infrastructure Build and Support mirror)
environment. If this variable is set, it indicates that a network peering was
established. This module uses it in the C<post_fail_hook> to clean up the
peering connection if the test fails.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::ipaddr2 qw(
  ipaddr2_patch_system
  ipaddr2_cleanup
  ipaddr2_logs_collect);

sub run {
    my ($self) = @_;
    select_serial_terminal;
    ipaddr2_patch_system();
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_logs_collect();
    ipaddr2_cleanup(
        diagnostic => get_var('IPADDR2_DIAGNOSTIC', 0),
        cloudinit => get_var('IPADDR2_CLOUDINIT', 1),
        ibsm_rg => get_var('IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
