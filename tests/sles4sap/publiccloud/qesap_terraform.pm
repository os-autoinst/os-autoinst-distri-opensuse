# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deploy public cloud infrastructure using terraform using qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

# Available OpenQA parameters:
# HA_CLUSTER - Enables HA/Hana cluster scenario
# NODE_COUNT - number of nodes to deploy. Needs to be >1 for cluster usage.
# PUBLIC_CLOUD_INSTANCE_TYPE - VM size, sets terraform 'vm_size' parameter
# USE_SAPCONF - (true/false) set 'false' to use saptune
# FENCING_MECHANISM - (sbd/native) choose fencing mechanism
# ISCSI_ENABLED - (true/false) choose if to deploy iscsi server
# QESAP_SCC_NO_REGISTER - define variable in openqa to skip SCC registration via ANSIBLE
# HANA_MEDIA - Hana install media directory
# HANA_ACCOUNT - Azure Storage name
# HANA_CONTAINER - Azure Container name
# HANA_KEYNAME - Azure key name in the Storage to generate SAS URI token used by hana_media in qe-sap-deployment
# _HANA_MASTER_PW (mandatory) - Hana master PW (secret)
# INSTANCE_SID - SAP Sid
# INSTANCE_ID - SAP instance id
# ANSIBLE_REMOTE_PYTHON - define python version to be used for qe-sap-deployment (default '/usr/bin/python3')
# PUBLIC_CLOUD_IMAGE_LOCATION - needed by get_blob_uri
# HANA_NAMESPACE - used to configure the Azure credentials involved in obtaining the HANA media
# SLES4SAP_FIREWALL_PORTS - if set to 'true' enable the firewall configuration during the HANA installation playbook

use base 'sles4sap_publiccloud_basetest';
use testapi;
use publiccloud::ssh_interactive 'select_host_console';
use publiccloud::instance;
use publiccloud::instances;
use publiccloud::utils qw(is_azure is_gce is_ec2 get_ssh_private_key_path is_byos detect_worker_ip);
use sles4sap_publiccloud;
use sles4sap::qesap::qesapdeployment;
use sles4sap::qesap::azure;
use sles4sap::azure_cli;
use sles4sap::ibsm;
use serial_terminal 'select_serial_terminal';
use registration qw(get_addon_fullname scc_version %ADDONS_REGCODE);
use qam;

our $ha_enabled = set_var_output('HA_CLUSTER', '0') =~ /false|0/i ? 0 : 1;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

=head2 set_var_output
    Check if a requested openQA variable is defined and returns it's current value.
    If the variable is not defined, it will:
     - defines it
     - assigns the default value provided
     - returns its value
    $variable - variable to check against OpenQA settings
    $default - default value to set in case the variable is missing.
=cut

sub set_var_output {
    my ($variable, $default) = @_;
    set_var($variable, get_var($variable, $default));
    return (get_var($variable));
}

sub run {
    my ($self, $run_args) = @_;
    my $provider_setting = get_required_var('PUBLIC_CLOUD_PROVIDER');

    # *_ADDRESS_RANGE variables are not necessary needed by all the conf.yaml templates
    # but calculate them every time is "cheap"
    my %maintenance_vars = ibsm_calculate_address_range(slot => get_required_var('WORKER_ID'));
    set_var("MAIN_ADDRESS_RANGE", $maintenance_vars{main_address_range});
    set_var("SUBNET_ADDRESS_RANGE", $maintenance_vars{subnet_address_range});


    # Collect OpenQA variables and default values
    set_var_output('NODE_COUNT', 1) unless ($ha_enabled);
    # Cluster needs at least 2 nodes
    die "HA cluster needs at least 2 nodes. Check 'NODE_COUNT' parameter." if ($ha_enabled && (get_var('NODE_COUNT') <= 1));

    set_var('FENCING_MECHANISM', 'native') unless ($ha_enabled);
    set_var('ISCSI_ENABLED', check_var('FENCING_MECHANISM', 'sbd') ? 'true' : 'false');
    set_var_output('ANSIBLE_REMOTE_PYTHON', '/usr/bin/python3');

    # Within the qe-sap-deployment terraform code, in each different CSP implementation,
    # an empty string means no peering.
    # This "trick" is needed to only have one conf.yaml
    # for both jobs that creates the peering with terraform or the az cli
    if (is_azure()) {
        set_var('IBSM_RG', '') unless (get_var('IBSM_RG'));
        set_var('IBSM_VNET', '') unless (get_var('IBSM_VNET'));
    } elsif (is_gce()) {
        die "Pering with NCC and using network_peering cannot be both active in the same config"
          if ((get_var('IBSM_VPC_NAME') || get_var('IBSM_SUBNET_NAME') || get_var('IBSM_SUBNET_REGION')) && get_var('IBSM_NCC_HUB'));
        set_var('IBSM_VPC_NAME', '') unless (get_var('IBSM_VPC_NAME'));
        set_var('IBSM_SUBNET_NAME', '') unless (get_var('IBSM_SUBNET_NAME'));
        set_var('IBSM_SUBNET_REGION', '') unless (get_var('IBSM_SUBNET_REGION'));
        set_var('IBSM_NCC_HUB', '') unless (get_var('IBSM_NCC_HUB'));
    } elsif (is_ec2()) {
        set_var('IBSM_PRJ_TAG', '') unless (get_var('IBSM_PRJ_TAG'));
    }

    # Select console on the host (not the PC instance) to reset 'TUNNELED',
    # otherwise select_serial_terminal() will be failed
    select_host_console();
    select_serial_terminal();

    # has to be after select_serial_terminal as detect_worker_ip
    # needs it.
    set_var("SLES4SAP_WORKER_IP",
        qesap_create_cidr_from_ip(
            ip => detect_worker_ip(proceed_on_failure => 1),
            proceed_on_failure => 1));

    my $deployment_name = deployment_name();
    # Create a QESAP_DEPLOYMENT_NAME variable so it includes the random
    # string appended to the PUBLIC_CLOUD_RESOURCE_GROUP
    #
    # User can :
    #  * define none of PUBLIC_CLOUD_RESOURCE_GROUP and QESAP_DEPLOYMENT_NAME
    #     resulting deployment_name: qesaposd123456
    #  * only define PUBLIC_CLOUD_RESOURCE_GROUP=goofy
    #     resulting deployment_name: goofy123456
    #  * define QESAP_DEPLOYMENT_NAME=goofy
    #     resulting deployment_name: goofy
    #     PUBLIC_CLOUD_RESOURCE_GROUP is completely ignored and
    #     the job_id is not included in the deployment name
    set_var('QESAP_DEPLOYMENT_NAME', get_var('QESAP_DEPLOYMENT_NAME', $deployment_name));
    record_info 'Resource Group', "Resource Group used for deployment: $deployment_name";

    my $provider = $self->provider_factory();
    set_var('SLES4SAP_PUBSSHKEY', get_ssh_private_key_path() . '.pub');

    # Needed to create the SAS URI token
    if (!is_azure()) {
        my $azure_client = publiccloud::azure_client->new();
        $azure_client->init(namespace => get_var('HANA_NAMESPACE', 'sapha'));
    }

    # variable to be conditionally used to hold ptf file names,
    # in case a PTF is installed
    my $ptf_files;
    # variable to hold the top level container where the PTF directory
    # is going to be
    my $ptf_container;
    my $ptf_token;

    if (get_var('PTF_ACCOUNT') && get_var('PTF_CONTAINER') && get_var('PTF_KEYNAME')) {
        $ptf_token = qesap_az_create_sas_token(
            storage => get_required_var('PTF_ACCOUNT'),
            container => (split("/", get_required_var('PTF_CONTAINER')))[0],
            keyname => get_required_var('PTF_KEYNAME'),
            # lifetime has to be enough to reach the point of the test that
            # executes qe-sap-deployment Ansible playbook 'ptf_installation.yaml'
            lifetime => 90,
            permission => 'rl');
        $ptf_files = qesap_az_list_container_files(
            storage => get_required_var('PTF_ACCOUNT'),
            container => (split("/", get_required_var('PTF_CONTAINER')))[0],
            token => $ptf_token,
            prefix => (split("/", get_required_var('PTF_CONTAINER')))[1]
        );
    }

    my $subscription_id = $provider->{provider_client}{subscription};
    my $os_image_name;

    if (is_azure() && get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        # This section is only needed by Azure tests using images uploaded
        # with publiccloud_upload_img. This is because qe-sap-deployment
        # is still not able to use images from Azure Gallery
        $os_image_name = $provider->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    } else {
        $os_image_name = $provider->get_image_id();
    }
    set_var('SLES4SAP_OS_IMAGE_NAME', $os_image_name);
    set_var_output('SLES4SAP_OS_OWNER', 'aws-marketplace') if is_ec2();

    # This is the path where community.sles-for-sap repo
    # has been cloned.
    # Not all the conf.yaml used by this file needs it but
    # it is just easier to define it here for all.
    set_var("ANSIBLE_ROLES", qesap_ansible_get_roles_dir());
    my $reg_mode = 'registercloudguest';    # Use registercloudguest by default
    if (get_var('QESAP_SCC_NO_REGISTER')) {
        $reg_mode = 'noreg';
    }
    elsif (get_var('QESAP_FORCE_SUSECONNECT')) {
        $reg_mode = 'suseconnect';
    }
    my $ansible_playbooks;
    my %playbook_configs = (
        ha_enabled => $ha_enabled,
        registration => $reg_mode,
        fencing => get_var('FENCING_MECHANISM'));

    if (get_var('PTF_ACCOUNT') && get_var('PTF_CONTAINER') && get_var('PTF_KEYNAME')) {
        $playbook_configs{ptf_files} = $ptf_files;
        $playbook_configs{ptf_token} = $ptf_token;
        $playbook_configs{ptf_container} = (split("/", get_required_var('PTF_CONTAINER')))[0];
        $playbook_configs{ptf_account} = get_required_var('PTF_ACCOUNT');
    }
    if ($playbook_configs{fencing} eq 'native' and is_azure()) {
        $playbook_configs{fence_type} = get_required_var('AZURE_FENCE_AGENT_CONFIGURATION');
        if ($playbook_configs{fence_type} eq 'spn') {
            $playbook_configs{spn_application_id} = get_var('AZURE_SPN_APPLICATION_ID', get_required_var('_SECRET_AZURE_SPN_APPLICATION_ID'));
            $playbook_configs{spn_application_password} = get_var('AZURE_SPN_APP_PASSWORD', get_required_var('_SECRET_AZURE_SPN_APP_PASSWORD'));
        }
    }

    $playbook_configs{scc_code} = get_required_var('SCC_REGCODE_SLES4SAP') if is_byos();
    my @addons = split(/,/, get_var('SCC_ADDONS', ''));
    # This implementation has a known limitation
    # if SCC_ADDONS has two or more elements (like "ltss,ltss_es")
    # only the last one will be added to the playbook argument.
    foreach my $addon (@addons) {
        my $name;
        # Keep the code simple by only support ltss addons,
        # it simplify version calculation.
        $name = get_addon_fullname($addon) if ($addon =~ 'ltss');
        if ($name) {
            $playbook_configs{ltss} = join(',', join('/', $name, scc_version(), 'x86_64'), $ADDONS_REGCODE{$name});
            $playbook_configs{registration} = 'suseconnect' if (is_byos() && $reg_mode !~ 'noreg');
        }
    }

    $playbook_configs{ibsm_ip} = get_var('IBSM_IP') if get_var('IBSM_IP');
    $playbook_configs{download_hostname} = get_var('REPO_MIRROR_HOST') if get_var('REPO_MIRROR_HOST');

    my @repos = get_test_repos();
    $playbook_configs{repos} = join(',', @repos);

    $ansible_playbooks = create_playbook_section_list(%playbook_configs);

    # Prepare QESAP deployment
    qesap_prepare_env(provider => $provider_setting, region => get_required_var('PUBLIC_CLOUD_REGION'));
    qesap_ansible_create_section(
        ansible_section => 'hana_vars',
        section_content => create_hana_vars_section()) if $ha_enabled;
    qesap_ansible_create_section(
        ansible_section => 'create',
        section_content => $ansible_playbooks) if @$ansible_playbooks;
    my @ansible_playbook_destroy = ('deregister.yaml');
    qesap_ansible_create_section(
        ansible_section => 'destroy',
        section_content => \@ansible_playbook_destroy) if @$ansible_playbooks;

    # Clean leftover peerings (Azure only)
    if (is_azure() && get_var('IBSM_RG')) {
        record_info 'PEERING CLEANUP', "Peering cleanup START";
        my $group = get_var('IBSM_RG');
        qesap_az_clean_old_peerings(rg => $group, vnet => az_network_vnet_get(resource_group => $group, query => "[0].name"));
        record_info 'PEERING CLEANUP', "Peering cleanup END";
    }
    elsif (is_ec2 && get_var('IBSM_PRJ_TAG')) {
        qesap_aws_delete_leftover_tgw_attachments(mirror_tag => get_var('IBSM_PRJ_TAG'));
    }

    # Regenerate config files (This workaround will be replaced with full yaml generator)
    qesap_prepare_env(provider => $provider_setting, only_configure => 1, region => get_required_var('PUBLIC_CLOUD_REGION'));

    my %retry_args = (
        logname => 'qesap_exec_terraform.log.txt',
        verbose => 1,
        timeout => 3600,
        error_list => [
            'An internal execution error occurred. Please retry later',
            'There is a peering operation in progress'
        ],
        destroy => 0);
    # Retrying terraform more times in case of GCP, to handle concurrent peering attempts
    $retry_args{retries} = is_gce() ? 5 : 2;
    $retry_args{cmd_options} = '--parallel ' . get_var('HANASR_TERRAFORM_PARALLEL') if get_var('HANASR_TERRAFORM_PARALLEL');
    my @ret = qesap_terraform_conditional_retry(%retry_args);
    die 'Terraform deployment FAILED. Check "qesap*" logs for details.' if ($ret[0]);

    # Sleep $N for fixing ansible "Missing sudo password" issue on GCP
    if (is_gce()) {
        sleep 60;
        record_info('Workaround: "sleep 60" for fixing ansible "Missing sudo password" issue on GCP');
    }

    $provider->terraform_applied(1);
    my $instances = create_instance_data(provider => $provider);
    foreach my $instance (@$instances) {
        record_info 'Instance', join(' ', 'IP: ', $instance->public_ip, 'Name: ', $instance->instance_id);
        $self->{my_instance} = $instance;
        $self->set_cli_ssh_opts;
        my $expected_hostname = $instance->{instance_id};
        # We need to scan for the SSH host key as the Ansible later
        $instance->update_instance_ip();
        $instance->wait_for_ssh();

        my $real_hostname = $instance->ssh_script_output(cmd => 'hostname', username => 'cloudadmin');
        # We expect hostnames reported by terraform to match the actual hostnames in Azure and GCE
        die "Expected hostname $expected_hostname is different than actual hostname [$real_hostname]"
          if ((is_azure() || is_gce()) && ($expected_hostname ne $real_hostname));
        if (get_var('FENCING_MECHANISM') eq 'native' && is_azure() && check_var('AZURE_FENCE_AGENT_CONFIGURATION', 'msi')) {
            qesap_az_setup_native_fencing_permissions(
                vm_name => $instance->instance_id,
                resource_group => qesap_az_get_resource_group());
        }
    }

    $self->{instances} = $run_args->{instances} = $instances;
    $self->{instance} = $run_args->{my_instance} = $run_args->{instances}[0];
    $self->{provider} = $run_args->{my_provider} = $provider;    # Required for cleanup
    record_info('Deployment OK',);
    return 1;
}

1;
