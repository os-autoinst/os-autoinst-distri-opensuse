# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Configuration steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use qesapdeployment;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Init al the PC gears (ssh keys)
    my $provider = $self->provider_factory();

    my $qesap_provider = lc get_required_var('PUBLIC_CLOUD_PROVIDER');

    my %variables;
    $variables{PROVIDER} = $qesap_provider;
    $variables{REGION} = $provider->provider_client->region;
    $variables{DEPLOYMENTNAME} = qesap_calculate_deployment_name('qesapval');
    if (get_var('QESAP_CLUSTER_OS_VER')) {
        $variables{OS_VER} = get_var('QESAP_CLUSTER_OS_VER');
    }
    else {
        $variables{STORAGE_ACCOUNT_NAME} = get_required_var('STORAGE_ACCOUNT_NAME');
        $variables{OS_VER} = $provider->get_image_id();
    }
    $variables{OS_OWNER} = get_var('QESAPDEPLOY_CLUSTER_OS_OWNER', 'amazon') if check_var('PUBLIC_CLOUD_PROVIDER', 'EC2');

    $variables{USE_SAPCONF} = get_var('QESAPDEPLOY_USE_SAPCONF');
    $variables{SSH_KEY_PRIV} = '/root/.ssh/id_rsa';
    $variables{SSH_KEY_PUB} = '/root/.ssh/id_rsa.pub';
    $variables{SCC_REGCODE_SLES4SAP} = get_required_var('SCC_REGCODE_SLES4SAP');
    $variables{HANA_INSTANCE_TYPE} = get_var('QESAP_HANA_INSTANCE_TYPE', 'r6i.xlarge');

    $variables{HANA_ACCOUNT} = get_required_var('QESAPDEPLOY_HANA_ACCOUNT');
    $variables{HANA_CONTAINER} = get_required_var('QESAPDEPLOY_HANA_CONTAINER');
    if (get_var("QESAPDEPLOY_HANA_TOKEN")) {
        $variables{HANA_TOKEN} = get_required_var('QESAPDEPLOY_HANA_TOKEN');
        # escape needed by 'sed'
        # but not implemented in file_content_replace() yet poo#120690
        $variables{HANA_TOKEN} =~ s/\&/\\\&/g;
    }
    $variables{HANA_SAR} = get_required_var("QESAPDEPLOY_SAPCAR");
    $variables{HANA_CLIENT_SAR} = get_required_var("QESAPDEPLOY_IMDB_CLIENT");
    $variables{HANA_SAPCAR} = get_required_var("QESAPDEPLOY_IMDB_SERVER");
    $variables{ANSIBLE_REMOTE_PYTHON} = get_var("QESAPDEPLOY_ANSIBLE_REMOTE_PYTHON", "/usr/bin/python3");
    if (check_var('PUBLIC_CLOUD_PROVIDER', 'GCE')) {
        $variables{HANA_DATA_DISK_TYPE} = get_var("QESAPDEPLOY_HANA_DISK_TYPE", "pd-ssd");
        $variables{HANA_LOG_DISK_TYPE} = get_var("QESAPDEPLOY_HANA_DISK_TYPE", "pd-ssd");
    }

    my %peering_settings = qesap_calculate_az_address_range(slot => get_required_var('WORKER_ID'));
    $variables{VNET_ADDRESS_RANGE} = $peering_settings{vnet_address_range};
    $variables{SUBNET_ADDRESS_RANGE} = $peering_settings{subnet_address_range};

    qesap_prepare_env(openqa_variables => \%variables, provider => $qesap_provider);
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
