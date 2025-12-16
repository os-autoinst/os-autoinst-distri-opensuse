# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Configure the environment for a qe-sap-deployment test run
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

qesapdeployment/configure.pm - Configure the environment for a qe-sap-deployment test run

=head1 DESCRIPTION

Prepares the environment for deploying an SAP HANA cluster using
the qe-sap-deployment framework. It gathers all necessary variables from
openQA settings, calculates dynamic values (like deployment name and IP ranges),
and generates the configuration files required by Terraform and Ansible.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider (e.g., 'AZURE', 'EC2', 'GCE').

=item B<QESAPDEPLOY_HANA_NAMESPACE>

(Azure-specific) The namespace for the HANA deployment. Defaults to 'sapha'.

=item B<QESAPDEPLOY_TERRAFORM_RUNNER>

The command to run Terraform. Defaults to 'terraform'.

=item B<QESAPDEPLOY_CLUSTER_OS_VER>

The OS version for the cluster nodes. Used if a catalog image is specified.

=item B<PUBLIC_CLOUD_IMAGE_LOCATION>

(Azure-specific) The location of a custom OS image in Azure Blob Storage.
Used instead of B<QESAPDEPLOY_CLUSTER_OS_VER>.

=item B<QESAPDEPLOY_CLUSTER_OS_OWNER>

(EC2-specific) The owner of the OS image. Defaults to 'amazon'.

=item B<WORKER_IP>

The IP address of the openQA worker, used to calculate CIDR ranges.

=item B<QESAPDEPLOY_USE_SAPCONF>

If 'true', configures the system using sapconf. Defaults to 'false'.

=item B<QESAPDEPLOY_USE_SAP_HANA_SR_ANGI>

If 'true', enables the SAP HANA SR Angi configuration. Defaults to 'false'.

=item B<QESAPDEPLOY_REGISTRATION_PLAYBOOK>

The name of the Ansible playbook for registration. Defaults to 'registration'.

=item B<QESAPDEPLOY_USE_SUSECONNECT>

If set, uses 'SUSEConnect' in the registration playbook.

=item B<SCC_ADDONS>

A comma-separated list of addon products to register (e.g., 'ltss').

=item B<SCC_REGCODE_SLES4SAP>

The registration code for SLES for SAP, required for BYOS images.

=item B<SCC_REGCODE_LTSS>

The registration code for the LTSS addon.

=item B<QESAPDEPLOY_SCC_LTSS_MODULE>

The name of the LTSS module to be enabled.

=item B<QESAPDEPLOY_GOOGLE_PROJECT>

(GCE-specific) The Google Cloud project ID.

=item B<QESAPDEPLOY_HANA_INSTANCE_TYPE>

(EC2-specific) The instance type for HANA VMs. Defaults to 'r6i.xlarge'.

=item B<QESAPDEPLOY_HANA_ACCOUNT>

The storage account for HANA installation media.

=item B<QESAPDEPLOY_HANA_CONTAINER>

The container within the storage account for HANA media.

=item B<QESAPDEPLOY_HANA_KEYNAME>

The key or credential name to access the HANA media storage.

=item B<QESAPDEPLOY_SAPCAR>

The filename of the SAPCAR binary.

=item B<QESAPDEPLOY_IMDB_CLIENT>

The filename of the HANA client SAR file.

=item B<QESAPDEPLOY_IMDB_SERVER>

The filename of the HANA server SAR file.

=item B<QESAPDEPLOY_HANA_FIREWALL>

If 'true', configures a firewall for HANA. Defaults to 'false'.

=item B<QESAPDEPLOY_ANSIBLE_REMOTE_PYTHON>

The path to the Python interpreter on the remote nodes. Defaults to '/usr/bin/python3'.

=item B<QESAPDEPLOY_FENCING>

The fencing mechanism to use (e.g., 'sbd', 'native'). Defaults to 'sbd'.

=item B<QESAPDEPLOY_HANA_DISK_TYPE>

(GCE-specific) The disk type for HANA data and log volumes. Defaults to 'pd-ssd'.

=item B<QESAPDEPLOY_AZURE_FENCE_AGENT_CONFIGURATION>

(Azure-specific) The configuration for the native fence agent ('msi' or 'spn').

=item B<QESAPDEPLOY_AZURE_SPN_APPLICATION_ID> or B<_SECRET_AZURE_SPN_APPLICATION_ID>

(Azure-specific) The application ID for the Service Principal Name used for fencing.

=item B<QESAPDEPLOY_AZURE_SPN_APP_PASSWORD> or B<_SECRET_AZURE_SPN_APP_PASSWORD>

(Azure-specific) The password for the Service Principal Name used for fencing.

=item B<QESAPDEPLOY_HANA_INSTALL_MODE>

The installation mode for HANA. Defaults to 'standard'.

=item B<QESAPDEPLOY_IBSM_VNET> and B<QESAPDEPLOY_IBSM_RG>

(Azure-specific) VNet and Resource Group of the IBSm for network peering.

=item B<QESAPDEPLOY_IBSM_PRJ_TAG>

(EC2-specific) The project tag of the IBSm for network peering.

=item B<QESAPDEPLOY_IBSM_VPC_NAME>, B<QESAPDEPLOY_IBSM_SUBNET_NAME>, B<QESAPDEPLOY_IBSM_SUBNET_REGION>, B<QESAPDEPLOY_IBSM_NCC_HUB>

(GCE-specific) Networking details of the IBSm for peering.

=item B<QESAPDEPLOY_IBSM_IP>

The IP address of the IBSm server, used for repository redirection.

=item B<QESAPDEPLOY_DOWNLOAD_HOSTNAME>

The hostname of the repository server to redirect to the IBSm.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use publiccloud::azure_client;
use publiccloud::utils qw(get_ssh_private_key_path detect_worker_ip);
use testapi;
use serial_terminal 'select_serial_terminal';
use registration qw(get_addon_fullname scc_version %ADDONS_REGCODE);
use qam 'get_test_repos';
use sles4sap::qesap::qesapdeployment;
use sles4sap::ibsm;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Init all the PC gears (ssh keys)
    my $provider = $self->provider_factory();
    my $provider_setting = get_required_var('PUBLIC_CLOUD_PROVIDER');

    # Needed to create the SAS URI token
    if ($provider_setting ne 'AZURE') {
        my $azure_client = publiccloud::azure_client->new();
        $azure_client->init(namespace => get_var('QESAPDEPLOY_HANA_NAMESPACE', 'sapha'));
    }

    my %variables;
    $variables{TERRAFORM_RUNNER} = get_var('QESAPDEPLOY_TERRAFORM_RUNNER', 'terraform');
    script_run(join(' ',
            'which', $variables{TERRAFORM_RUNNER}, '&&',
            $variables{TERRAFORM_RUNNER}, '--version', '||',
            'echo', "\"'" . $variables{TERRAFORM_RUNNER} . "' tool not available in the path\""));

    $variables{REGION} = $provider->provider_client->region;
    $variables{DEPLOYMENTNAME} = qesap_calculate_deployment_name('qesapval');
    if (get_var('QESAPDEPLOY_CLUSTER_OS_VER')) {
        $variables{OS_VER} = get_var('QESAPDEPLOY_CLUSTER_OS_VER');
    }
    elsif ($provider_setting eq 'AZURE') {
        $variables{OS_URI} = $provider->get_blob_uri(get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    }
    else
    {
        $variables{OS_VER} = $provider->get_image_id();
    }
    $variables{OS_OWNER} = get_var('QESAPDEPLOY_CLUSTER_OS_OWNER', 'amazon') if ($provider_setting eq 'EC2');

    my $worker_ip = qesap_create_cidr_from_ip(ip => detect_worker_ip(proceed_on_failure => 1), proceed_on_failure => 1);
    $variables{WORKER_IP} = $worker_ip || '';

    $variables{USE_SAPCONF} = get_var('QESAPDEPLOY_USE_SAPCONF', 'false');
    $variables{USE_SR_ANGI} = get_var('QESAPDEPLOY_USE_SAP_HANA_SR_ANGI', 'false');
    $variables{SLES4SAP_PUBSSHKEY} = get_ssh_private_key_path() . '.pub';
    $variables{REGISTRATION_PLAYBOOK} = get_var('QESAPDEPLOY_REGISTRATION_PLAYBOOK', 'registration');
    $variables{REGISTRATION_PLAYBOOK} =~ s/\.yaml$//;

    my $reg_args;
    $reg_args = "-e use_suseconnect=true " if (get_var('QESAPDEPLOY_USE_SUSECONNECT'));
    my @addons = split(/,/, get_var('SCC_ADDONS', ''));
    # This implementation has a known limitation
    # if SCC_ADDONS has two or more elements (like "ltss,ltss_es")
    # only the first one will be added to the playbook argument.
    foreach my $addon (@addons) {
        my $name;
        # Keep the code simple by only support ltss addons,
        # it simplifies version calculation.
        $name = get_addon_fullname($addon) if ($addon =~ 'ltss');
        if ($name) {
            $reg_args .= qesap_ansible_reg_module(reg => join(',', join('/', $name, scc_version(), 'x86_64'), $ADDONS_REGCODE{$name}));
            # exit from the addons loop not to pack on the playbook command line more than one "-e sles_module"
            last;
        }
    }
    $variables{REG_ARGS} = $reg_args;

    # Only BYOS images needs it
    $variables{SCC_REGCODE_SLES4SAP} = get_var('SCC_REGCODE_SLES4SAP', '');
    $variables{SCC_LTSS_REGCODE} = get_var('SCC_REGCODE_LTSS', '');
    $variables{SCC_LTSS_MODULE} = get_var('QESAPDEPLOY_SCC_LTSS_MODULE', '');

    $variables{GOOGLE_PROJECT} = get_required_var('QESAPDEPLOY_GOOGLE_PROJECT') if ($provider_setting eq 'GCE');
    $variables{HANA_INSTANCE_TYPE} = get_var('QESAPDEPLOY_HANA_INSTANCE_TYPE', 'r6i.xlarge') if ($provider_setting eq 'EC2');

    $variables{HANA_ACCOUNT} = get_required_var('QESAPDEPLOY_HANA_ACCOUNT');
    $variables{HANA_CONTAINER} = get_required_var('QESAPDEPLOY_HANA_CONTAINER');
    $variables{HANA_KEYNAME} = get_required_var('QESAPDEPLOY_HANA_KEYNAME');
    $variables{HANA_SAR} = get_required_var('QESAPDEPLOY_SAPCAR');
    $variables{HANA_CLIENT_SAR} = get_required_var('QESAPDEPLOY_IMDB_CLIENT');
    $variables{HANA_SAPCAR} = get_required_var('QESAPDEPLOY_IMDB_SERVER');
    $variables{HANA_FIREWALL} = get_var('QESAPDEPLOY_HANA_FIREWALL', 'false');
    $variables{ANSIBLE_REMOTE_PYTHON} = get_var('QESAPDEPLOY_ANSIBLE_REMOTE_PYTHON', '/usr/bin/python3');
    $variables{FENCING} = get_var('QESAPDEPLOY_FENCING', 'sbd');
    if ($provider_setting eq 'GCE') {
        $variables{HANA_DATA_DISK_TYPE} = get_var('QESAPDEPLOY_HANA_DISK_TYPE', 'pd-ssd');
        $variables{HANA_LOG_DISK_TYPE} = get_var('QESAPDEPLOY_HANA_DISK_TYPE', 'pd-ssd');
    }

    # *_ADDRESS_RANGE variables are not necessary needed by all the conf.yaml templates
    # but calculate them every time is "cheap"
    my %peering_settings = ibsm_calculate_address_range(slot => get_required_var('WORKER_ID'));
    $variables{MAIN_ADDRESS_RANGE} = $peering_settings{main_address_range};
    if ($provider_setting eq 'AZURE') {
        $variables{SUBNET_ADDRESS_RANGE} = $peering_settings{subnet_address_range};
        if ($variables{FENCING} eq 'native') {
            $variables{AZURE_NATIVE_FENCING_AIM} = get_var('QESAPDEPLOY_AZURE_FENCE_AGENT_CONFIGURATION', 'msi');
            if ($variables{AZURE_NATIVE_FENCING_AIM} eq 'spn') {
                $variables{AZURE_NATIVE_FENCING_APP_ID} = get_var('QESAPDEPLOY_AZURE_SPN_APPLICATION_ID', get_required_var('_SECRET_AZURE_SPN_APPLICATION_ID'));
                $variables{AZURE_NATIVE_FENCING_APP_PASSWORD} = get_var('QESAPDEPLOY_AZURE_SPN_APP_PASSWORD', get_required_var('_SECRET_AZURE_SPN_APP_PASSWORD'));
            }
        }
    }

    $variables{ANSIBLE_ROLES} = qesap_ansible_get_roles_dir();
    $variables{HANA_INSTALL_MODE} = get_var('QESAPDEPLOY_HANA_INSTALL_MODE', 'standard');

    # Default to empty string is intentional:
    # empty value is used in terraform not to create the deployment
    if ($provider_setting eq 'AZURE') {
        $variables{IBSM_VNET} = get_var('QESAPDEPLOY_IBSM_VNET', '');
        $variables{IBSM_RG} = get_var('QESAPDEPLOY_IBSM_RG', '');
    }
    elsif ($provider_setting eq 'EC2') {
        $variables{IBSM_PRJ_TAG} = get_var('QESAPDEPLOY_IBSM_PRJ_TAG', '');
    }
    elsif ($provider_setting eq 'GCE') {
        $variables{IBSM_VPC_NAME} = get_var('QESAPDEPLOY_IBSM_VPC_NAME', '');
        $variables{IBSM_SUBNET_NAME} = get_var('QESAPDEPLOY_IBSM_SUBNET_NAME', '');
        $variables{IBSM_SUBNET_REGION} = get_var('QESAPDEPLOY_IBSM_SUBNET_REGION', '');
        $variables{IBSM_NCC_HUB} = get_var('QESAPDEPLOY_IBSM_NCC_HUB', '');
    }

    if (($provider_setting eq 'AZURE' && get_var('QESAPDEPLOY_IBSM_VNET') && get_var('QESAPDEPLOY_IBSM_RG')) ||
        ($provider_setting eq 'EC2' && get_var('QESAPDEPLOY_IBSM_PRJ_TAG')) ||
        ($provider_setting eq 'GCE' && get_var('QESAPDEPLOY_IBSM_VPC_NAME') && get_var('QESAPDEPLOY_IBSM_SUBNET_NAME') && get_var('QESAPDEPLOY_IBSM_SUBNET_REGION')) ||
        ($provider_setting eq 'GCE' && get_var('QESAPDEPLOY_IBSM_NCC_HUB'))
    ) {
        $variables{IBSM_IP} = get_required_var('QESAPDEPLOY_IBSM_IP');
        $variables{DOWNLOAD_HOSTNAME} = get_required_var('QESAPDEPLOY_DOWNLOAD_HOSTNAME');
        $variables{REPOS} = join(',', get_test_repos());
    }

    qesap_prepare_env(
        openqa_variables => \%variables,
        provider => get_required_var('PUBLIC_CLOUD_PROVIDER'),
        region => $provider->provider_client->region);
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
