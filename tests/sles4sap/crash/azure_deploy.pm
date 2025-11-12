# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: This module is responsible for creating all necessary Azure resources:
# - Azure Resource Group
# - Network Security Group and SSH rule
# - Virtual Network and Subnet
# - Public IP and NIC
# - VM creation from image or VHD blob
# It saves VM public IP and SSH command into job variables

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils;
use serial_terminal 'select_serial_terminal';
use sles4sap::crash;

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for this test')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;
    my $provider = $self->provider_factory();

    my $os_ver;
    if (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        $os_ver = $self->{provider}->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    } else {
        $os_ver = $provider->get_image_id();
    }
    assert_script_run('rm ~/.ssh/config');

    crash_deploy_azure(os => $os_ver, region => $provider->provider_client->region);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    crash_destroy_azure();
    $self->SUPER::post_fail_hook;
}

1;
