# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: create a deployment with a single VM on Microsoft Azure cloud.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

cloud_zypper_patch/deploy.pm - Deploy a single VM on Microsoft Azure

=head1 DESCRIPTION

This module deploys a single virtual machine (VM) on Microsoft Azure to be used
as a System Under Test (SUT) for patching tests.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<PUBLIC_CLOUD_IMAGE_ID>

The ID of the Azure image to be used for the VM deployment.

=item B<PUBLIC_CLOUD_IMAGE_LOCATION>

The location of the Azure image to be used for the VM deployment. This is used
if B<PUBLIC_CLOUD_IMAGE_ID> is not set.

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

    # Init all the PC gears (ssh keys, CSP credentials)
    my $provider = $self->provider_factory();

    zp_azure_deploy(
        region => $provider->provider_client->region,
        os => $provider->get_image_id());
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    zp_azure_destroy();
    $self->SUPER::post_fail_hook;
}

1;
