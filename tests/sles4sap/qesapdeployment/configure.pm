# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Configuration steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use publiccloud::azure_client;
use publiccloud::utils qw(get_ssh_private_key_path);
use testapi;
use serial_terminal 'select_serial_terminal';
use qesapdeployment;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Init all the PC gears (ssh keys)
    my $provider = $self->provider_factory();

    # Needed to create the SAS URI token
    if (!check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        my $azure_client = publiccloud::azure_client->new();
        $azure_client->init();
    }

    my %variables;
    $variables{REGION} = $provider->provider_client->region;
    $variables{DEPLOYMENTNAME} = qesap_calculate_deployment_name('qesapval');
    if (get_var('QESAPDEPLOY_CLUSTER_OS_VER')) {
        $variables{OS_VER} = get_var('QESAPDEPLOY_CLUSTER_OS_VER');
    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        $variables{STORAGE_ACCOUNT_NAME} = get_required_var('STORAGE_ACCOUNT_NAME');
        $variables{OS_URI} = $provider->get_blob_uri(get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    }
    else
    {
        $variables{OS_VER} = $provider->get_image_id();
    }
    $variables{OS_OWNER} = get_var('QESAPDEPLOY_CLUSTER_OS_OWNER', 'amazon') if check_var('PUBLIC_CLOUD_PROVIDER', 'EC2');

    $variables{USE_SAPCONF} = get_var('QESAPDEPLOY_USE_SAPCONF', 'false');
    $variables{SLES4SAP_PUBSSHKEY} = get_ssh_private_key_path() . '.pub';
    $variables{REGISTRATION_PLAYBOOK} = get_var('QESAPDEPLOY_REGISTRATION_PLAYBOOK', 'registration');
    $variables{REGISTRATION_PLAYBOOK} =~ s/\.yaml$//;
    $variables{SUSECONNECT} = get_var('QESAPDEPLOY_USE_SUSECONNECT', 'false');

    # Only BYOS images needs it
    $variables{SCC_REGCODE_SLES4SAP} = get_var('SCC_REGCODE_SLES4SAP', '');
    $variables{SCC_LTSS_REGCODE} = get_var('SCC_REGCODE_LTSS', '');
    $variables{SCC_LTSS_MODULE} = get_var('QESAPDEPLOY_SCC_LTSS_MODULE', '');
    if (check_var('PUBLIC_CLOUD_PROVIDER', 'EC2')) {
        $variables{HANA_INSTANCE_TYPE} = get_var('QESAPDEPLOY_HANA_INSTANCE_TYPE', 'r6i.xlarge');
    }

    $variables{HANA_ACCOUNT} = get_required_var('QESAPDEPLOY_HANA_ACCOUNT');
    $variables{HANA_CONTAINER} = get_required_var('QESAPDEPLOY_HANA_CONTAINER');
    $variables{HANA_KEYNAME} = get_required_var('QESAPDEPLOY_HANA_KEYNAME');
    $variables{HANA_SAR} = get_required_var('QESAPDEPLOY_SAPCAR');
    $variables{HANA_CLIENT_SAR} = get_required_var('QESAPDEPLOY_IMDB_CLIENT');
    $variables{HANA_SAPCAR} = get_required_var('QESAPDEPLOY_IMDB_SERVER');
    $variables{ANSIBLE_REMOTE_PYTHON} = get_var('QESAPDEPLOY_ANSIBLE_REMOTE_PYTHON', '/usr/bin/python3');
    $variables{FENCING} = get_var('QESAPDEPLOY_FENCING', 'sbd');
    if (check_var('PUBLIC_CLOUD_PROVIDER', 'GCE')) {
        $variables{HANA_DATA_DISK_TYPE} = get_var('QESAPDEPLOY_HANA_DISK_TYPE', 'pd-ssd');
        $variables{HANA_LOG_DISK_TYPE} = get_var('QESAPDEPLOY_HANA_DISK_TYPE', 'pd-ssd');
    }

    if (check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        my %peering_settings = qesap_az_calculate_address_range(slot => get_required_var('WORKER_ID'));
        $variables{VNET_ADDRESS_RANGE} = $peering_settings{vnet_address_range};
        $variables{SUBNET_ADDRESS_RANGE} = $peering_settings{subnet_address_range};
        if ($variables{FENCING} eq 'native') {
            $variables{AZURE_NATIVE_FENCING_AIM} = get_var('QESAPDEPLOY_AZURE_FENCE_AGENT_CONFIGURATION', 'msi');
            if ($variables{AZURE_NATIVE_FENCING_AIM} eq 'spn') {
                $variables{AZURE_NATIVE_FENCING_APP_ID} = get_var('QESAPDEPLOY_AZURE_SPN_APPLICATION_ID', get_required_var('_SECRET_AZURE_SPN_APPLICATION_ID'));
                $variables{AZURE_NATIVE_FENCING_APP_PASSWORD} = get_var('QESAPDEPLOY_AZURE_SPN_APP_PASSWORD', get_required_var('_SECRET_AZURE_SPN_APP_PASSWORD'));
            }
        }
    }

    $variables{ANSIBLE_ROLES} = qesap_get_ansible_roles_dir();

    qesap_prepare_env(
        openqa_variables => \%variables,
        provider => get_required_var('PUBLIC_CLOUD_PROVIDER')
    );
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}

1;
