# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Testmodule to upload images to CSP
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base "opensusebasetest";
use strict;
use testapi;
use utils;
use serial_terminal 'select_virtio_console';
use version_utils 'is_sle';
use registration 'add_suseconnect_product';
use publiccloud::ec2;
use publiccloud::azure;

sub prepare_os {

    if (is_sle) {
        my $modver = get_required_var('VERSION') =~ s/-SP\d+//r;
        add_suseconnect_product('sle-module-public-cloud', $modver);
    }

    if (check_var('PUBLIC_CLOUD_PROVIDER', 'EC2')) {
        if (is_sle) {
            # disable Cloud_tools for this test
            zypper_call('rr Cloud_Tools');
            if (script_run('pip list | grep awscli') == 0) {
                assert_script_run('pip uninstall -y awscli');
            }
            zypper_call('ref');
            zypper_call('in aws-cli');
        }
        zypper_call('in python-ec2uploadimg');
        assert_script_run("curl " . data_url('publiccloud/ec2utils.conf') . " -o /root/.ec2utils.conf");
    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        zypper_call('in curl');
        assert_script_run('sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc');
        zypper_call('addrepo --name "Azure CLI" --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli');
        zypper_call('install --from azure-cli -y azure-cli');
    }
}

sub provider_factory {
    if (check_var('PUBLIC_CLOUD_PROVIDER', 'EC2')) {
        return publiccloud::ec2->new(
            key_id     => get_required_var('PUBLIC_CLOUD_KEY_ID'),
            key_secret => get_required_var('PUBLIC_CLOUD_KEY_SECRET'),
            region     => get_var('PUBLIC_CLOUD_REGION', 'eu-central-1')
        );

    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        return publiccloud::azure->new(
            key_id     => get_required_var('PUBLIC_CLOUD_KEY_ID'),
            key_secret => get_required_var('PUBLIC_CLOUD_KEY_SECRET'),
            region     => get_var('PUBLIC_CLOUD_REGION', 'westeurope'),
            tenantid   => get_required_var('PUBLIC_CLOUD_TENANT_ID')
        );
    }
    else {
        die('Unknown PUBLIC_CLOUD_PROVIDER given');
    }
}

sub run {
    my ($self) = @_;
    select_virtio_console();

    prepare_os();

    my $provider = $self->{provider} = provider_factory();
    $provider->init;

    my $img_url = get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    my ($img_name) = $img_url =~ /([^\/]+)$/;

    if (my $img_id = $provider->find_img($img_name)) {
        record_info("Image $img_name already exists!");
        set_var('PUBLIC_CLOUD_IMAGE_ID', $img_id);
        return;
    }

    assert_script_run("wget $img_url -O $img_name", timeout => 60 * 10);

    my $img_id = $provider->upload_img($img_name);

    set_var('PUBLIC_CLOUD_IMAGE_ID', $img_id);

    $provider->cleanup();
}

sub post_fail_hook {
    my ($self) = @_;

    if ($self->{provider}) {
        $self->{provider}->cleanup();
    }
}

sub test_flags {
    return {fatal => 1};
}


1;

=head1 Discussion

OpenQA script to upload images into public cloud. This test module is only
added if PUBLIC_CLOUD_IMAGE_LOCATION is set.

=head1 Configuration

=head2 PUBLIC_CLOUD_PROVIDER

The type of the CSP (e.g. AZURE, EC2)

=head2 PUBLIC_CLOUD_IMAGE_LOCATION

The URL where the image gets downloaded from. The name of the image gets extracted
from this URL.

=head2 PUBLIC_CLOUD_KEY_ID

The CSP credentials key-id to used to access API.

=head2 PUBLIC_CLOUD_KEY_SECRET

The CSP credentials secret used to access API.

=head2 PUBLIC_CLOUD_REGION

The region to use. (default-azure: westeurope, default-ec2: eu-central-1)

=head2 PUBLIC_CLOUD_TENANT_ID

This is B<only for azure> and used to create the service account file.

=cut
