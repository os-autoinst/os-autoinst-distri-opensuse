# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deploy the SUT for the ipaddr2 test
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/deploy.pm - Perform the infrastructure deployment for the ipaddr2 test

=head1 DESCRIPTION

This module deploys the infrastructure for the ipaddr2 test.
It creates the necessary resources in Azure, which includes:

- One bastion VM, serving as an entry point to the infrastructure.
- Two VMs that will be later joined in a crm cluster, forming the SUT (System Under Test).

=head1 SETTINGS

=over

=item B<IPADDR2_CLOUDINIT>

Enables or disables the use of cloud-init for SUT setup. Defaults to enabled (1).
When enabled, cloud-init handles tasks such as image registration,
installation of nginx and socat, and creation of a basic web page for SUT identification.

=item B<IPADDR2_NGINX_EXTREPO>

External repository for nginx installation. Needed when testing OS images
not including nginx by default.
If set, it will be used to install nginx during the cloud-init phase.

=item B<IPADDR2_DIAGNOSTIC>

Enable some diagnostic features as the additional deployment of some Azure resources needed
to collect boot logs.

=item B<IPADDR2_TRUSTEDLAUNCH>

Enable trusted launch for the VMs.

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider for deployment. Currently, only AZURE is supported.

=item B<PUBLIC_CLOUD_IMAGE_LOCATION> and B<PUBLIC_CLOUD_IMAGE_ID>

Id of the OS images to use for the VMs deployment.
If B<PUBLIC_CLOUD_IMAGE_LOCATION> is set, it is used to specify the location 
of a custom image in Azure Blob Storage uploaded via B<publiccloud_upload_img>.
If not set, a catalog image specified via B<PUBLIC_CLOUD_IMAGE_ID>
is used.

=item B<SCC_REGCODE_SLES4SAP>

SUSE Customer Center registration code for SLES for SAP.
Required if the OS image is BYOS.

=item B<SCC_ADDONS>

SUSE Customer Center addons to register during the deployment.
Currently, this is not implemented via cloud-init script.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::ipaddr2 qw(
  ipaddr2_cloudinit_create
  ipaddr2_infra_deploy
  ipaddr2_deployment_sanity
  ipaddr2_cleanup
  ipaddr2_logs_collect);

sub run {
    my ($self) = @_;

    # Try to catch as many variable issues as possible
    # before to start.
    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    # Init all the PC gears (ssh keys, CSP credentials)
    my $provider = $self->provider_factory();
    # remove configuration file created by the PC factory
    # as it interfere with ssh behavior.
    # in particular it has setting about verbosity that
    # break test steps that relay to remote ssh command output
    assert_script_run('rm ~/.ssh/config');

    my $os;
    if (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        # This section is only needed by Azure tests using images uploaded
        # with publiccloud_upload_img. This is because qe-sap-deployment
        # is still not able to use images from Azure Gallery
        $os = $provider->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    } else {
        $os = $provider->get_image_id();
    }

    my %cloudinit_args;
    # This line of code is not really specific to cloud-init,
    # but it is used to ensure that registration code is available
    # when using BYOS image. No matter if the registration is performed
    # via cloud-init or not.
    $cloudinit_args{scc_code} = get_required_var('SCC_REGCODE_SLES4SAP') if ($os =~ /byos/i);

    die "SCC_ADDONS registration is not implemented via cloudinit script yet"
      if (get_var('SCC_ADDONS') && !check_var('IPADDR2_CLOUDINIT', 0));

    $cloudinit_args{external_repo} = get_var('IPADDR2_NGINX_EXTREPO') if get_var('IPADDR2_NGINX_EXTREPO');
    my %deployment = (
        os => $os,
        diagnostic => get_var('IPADDR2_DIAGNOSTIC', 0));
    $deployment{trusted_launch} = 0 if (check_var('IPADDR2_TRUSTEDLAUNCH', 0));

    $deployment{region} = $provider->provider_client->region;
    # If required (by default cloud-init is active), both:
    #   - create on the fly the cloud-init profile
    #   - activate the cloud-init part in the deployment
    $deployment{cloudinit_profile} = ipaddr2_cloudinit_create(%cloudinit_args) unless (check_var('IPADDR2_CLOUDINIT', 0));

    ipaddr2_infra_deploy(%deployment);

    ipaddr2_deployment_sanity();
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_logs_collect();
    ipaddr2_cleanup(diagnostic => get_var('IPADDR2_DIAGNOSTIC', 0),
        cloudinit => get_var('IPADDR2_CLOUDINIT', 1));
    $self->SUPER::post_fail_hook;
}

1;
