# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create a VM with a single NIC and 3 ip-config
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

# Variables:
#  IPADDR2_CLOUDINIT: 0:disabled|1:enabled. Default to enabled. Control if cloud-init is used to setup the SUT.
#                     cloud-init in this test can handle:
#                       1. register the image
#                       2. ensure nginx and socat are installed
#                       3. create a simple web page presented by default by nginx and allowing to recognize
#                          which of the two internal VM are providing it.

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::ipaddr2 qw(
  ipaddr2_cloudinit_create
  ipaddr2_infra_deploy
  ipaddr2_deployment_logs
  ipaddr2_deployment_sanity
  ipaddr2_infra_destroy
  ipaddr2_cloudinit_logs
);

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
    # break test steps that relay to remote ssh comman output
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
    $cloudinit_args{scc_code} = get_required_var('SCC_REGCODE_SLES4SAP') if ($os =~ /byos/i);
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
    ipaddr2_deployment_logs() if check_var('IPADDR2_DIAGNOSTIC', 1);
    ipaddr2_cloudinit_logs() unless check_var('IPADDR2_CLOUDINIT', 0);
    ipaddr2_infra_destroy();
    $self->SUPER::post_fail_hook;
}

1;
