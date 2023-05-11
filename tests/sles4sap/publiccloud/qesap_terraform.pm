# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Deploy public cloud infrastructure using terraform using qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

# Available OpenQA parameters:
# HA_CLUSTER - Enables HA/Hana cluser scenario
# NODE_COUNT - number of nodes to deploy. Needs to be >1 for cluster usage.
# PUBLIC_CLOUD_INSTANCE_TYPE - VM size, sets terraform 'vm_size' parameter
# USE_SAPCONF - (true/false) set 'false' to use saptune
# HANA_OS_MAJOR_VERSION - sets 'hana_os_major_version' terraform parameter - default is taken from 'VERSION'
# FENCING_MECHANISM - (sbd/native) choose fencing mechanism
# QESAP_SCC_NO_REGISTER - define variable in openqa to skip SCC registration via ANSIBLE
# HANA_MEDIA - Hana install media directory
# _HANA_MASTER_PW (mandatory) - Hana master PW (secret)
# INSTANCE_SID - SAP Sid
# INSTANCE_ID - SAP instance id


use base 'sles4sap_publiccloud_basetest';
use publiccloud::ssh_interactive 'select_host_console';
use strict;
use warnings;
use testapi;
use Mojo::File 'path';
use publiccloud::utils;
use publiccloud::instance;
use publiccloud::instances;
use qesapdeployment;
use sles4sap_publiccloud;
use serial_terminal 'select_serial_terminal';
use YAML::PP;
use mmapi qw(get_current_job_id);

our $ha_enabled = set_var_output('HA_CLUSTER', '0') =~ /false|0/i ? 0 : 1;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

=head2 set_var_output
    Check if requested openQA variable is defined and returns it's current value.
    If the variable is not defined, it will set up the default value provided and returns it.
    $variable - variable to check against OpenQA settings
    $default - default value to set in case the variable is missing.
=cut

sub set_var_output {
    my ($variable, $default) = @_;
    set_var($variable, get_var($variable, $default));
    return (get_var($variable));
}

=head2 create_ansible_playbook_list

    Detects HANA/HA scenario from openQA variables and returns a list of ansible playbooks to include
    in the "ansible: create:" section of config.yaml file.

=cut

sub create_playbook_section_list {
    # Cluster related setup
    my @playbook_list;
    my @hana_playbook_list;

    # Add registration module as first element - "QESAP_SCC_NO_REGISTER" skips scc registration via ansible
    push @playbook_list, 'registration.yaml -e reg_code=' . get_required_var('SCC_REGCODE_SLES4SAP') . " -e email_address=''"
      unless (get_var('QESAP_SCC_NO_REGISTER'));

    # SLES4SAP/HA related playbooks
    if ($ha_enabled) {
        push @hana_playbook_list, 'pre-cluster.yaml', 'sap-hana-preconfigure.yaml -e use_sapconf=' . set_var_output('USE_SAPCONF', 'true');
        push @hana_playbook_list, 'cluster_sbd_prep.yaml' if (check_var('FENCING_MECHANISM', 'sbd'));
        push @hana_playbook_list, qw(
          sap-hana-storage.yaml
          sap-hana-download-media.yaml
          sap-hana-install.yaml
          sap-hana-system-replication.yaml
          sap-hana-system-replication-hooks.yaml
          sap-hana-cluster.yaml
        );
        # Push whole playbook list
        push(@playbook_list, @hana_playbook_list);
    }
    return (\@playbook_list);
}

=head2 create_hana_vars_section

    Detects HANA/HA scenario from openQA variables and creates "terraform: variables:" section in config.yaml file.

=cut

sub create_hana_vars_section {
    # Cluster related setup
    my %hana_vars;
    if ($ha_enabled == 1) {
        $hana_vars{sap_hana_install_software_directory} = get_required_var('HANA_MEDIA');
        $hana_vars{sap_hana_install_master_password} = get_required_var('_HANA_MASTER_PW');
        $hana_vars{sap_hana_install_sid} = get_required_var('INSTANCE_SID');
        $hana_vars{sap_hana_install_instance_number} = get_required_var('INSTANCE_ID');
        $hana_vars{sap_domain} = get_var('SAP_DOMAIN', 'qesap.example.com');
        $hana_vars{primary_site} = get_var('HANA_PRIMARY_SITE', 'site_a');
        $hana_vars{secondary_site} = get_var('HANA_SECONDARY_SITE', 'site_b');
        set_var('SAP_SIDADM', lc(get_var('INSTANCE_SID') . 'adm'));
    }
    return (\%hana_vars);
}

=head2 create_instance_data

    Create and populate a list of publiccloud::instance and publiccloud::provider compatible
    class instances.

=cut

sub create_instance_data {
    my $provider = shift;
    my $class = ref($provider);
    die "Unexpected class type [$class]" unless ($class =~ /^publiccloud::(azure|ec2|gce)/);
    my @instances = ();
    my $inventory_file = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my $ypp = YAML::PP->new;
    my $raw_file = script_output("cat $inventory_file");
    my $inventory_data = $ypp->load_string($raw_file)->{all}{children};

    for my $type_label (keys %$inventory_data) {
        my $type_data = $inventory_data->{$type_label}{hosts};
        for my $vm_label (keys %$type_data) {
            my $instance = publiccloud::instance->new(
                public_ip => $type_data->{$vm_label}->{ansible_host},
                instance_id => $vm_label,
                username => get_required_var('PUBLIC_CLOUD_USER'),
                ssh_key => '~/.ssh/id_rsa',
                provider => $provider,
                region => $provider->provider_client->region,
                type => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
                image_id => $provider->get_image_id());
            push @instances, $instance;
        }
    }
    publiccloud::instances::set_instances(@instances);
    return \@instances;
}

sub run {
    my ($self, $run_args) = @_;

    if (check_var('IS_MAINTENANCE', 1)) {
        my %maintenance_vars = qesap_calculate_az_address_range(slot => get_var("WORKER_INSTANCE"));
        set_var("VNET_ADDRESS_RANGE", $maintenance_vars{vnet_address_range});
        set_var("SUBNET_ADDRESS_RANGE", $maintenance_vars{subnet_address_range});
    }

    # Let's define a workspace for terraform. We use PUBLIC_CLOUD_RESOURCE_GROUP
    # if defined, otherwise we use qesaposd
    my $workspace = get_var('PUBLIC_CLOUD_RESOURCE_GROUP', 'qesaposd') . get_current_job_id();

    # Select console on the host (not the PC instance) to reset 'TUNNELED',
    # otherwise select_serial_terminal() will be failed
    select_host_console();
    select_serial_terminal();

    # Collect OpenQA variables and default values
    set_var_output('NODE_COUNT', 1) unless ($ha_enabled);
    set_var_output('HANA_OS_MAJOR_VERSION', (split('-', get_var('VERSION')))[0]);
    # Cluster needs at least 2 nodes
    die "HA cluster needs at least 2 nodes. Check 'NODE_COUNT' parameter." if ($ha_enabled && (get_var('NODE_COUNT') <= 1));

    set_var('FENCING_MECHANISM', 'native') unless ($ha_enabled);
    if (is_azure) {
        # Update PUBLIC_CLOUD_RESOURCE_GROUP in Azure's tests so it includes the random
        # string appended to the workspace
        set_var('PUBLIC_CLOUD_RESOURCE_GROUP', $workspace);
        record_info 'Resource Group', "Resource Group used for deployment: $workspace";
    }

    if (get_var("HANA_TOKEN")) {
        my $escaped_token = get_required_var("HANA_TOKEN");
        # escape needed by 'sed'
        # but not implemented in file_content_replace() yet poo#120690
        $escaped_token =~ s/\&/\\\&/g;
        set_var("HANA_TOKEN", $escaped_token);
    }


    my $provider = $self->provider_factory();
    set_var('SLE_IMAGE', $provider->get_image_id());
    my $ansible_playbooks = create_playbook_section_list();
    my $ansible_hana_vars = create_hana_vars_section();

    # Prepare QESAP deplyoment
    qesap_prepare_env(provider => lc(get_required_var('PUBLIC_CLOUD_PROVIDER')));
    qesap_create_ansible_section(ansible_section => 'create', section_content => $ansible_playbooks) if @$ansible_playbooks;
    qesap_create_ansible_section(ansible_section => 'hana_vars', section_content => $ansible_hana_vars) if %$ansible_hana_vars;

    # Regenerate config files (This workaround will be replaced with full yaml generator)
    qesap_prepare_env(provider => lc(get_required_var('PUBLIC_CLOUD_PROVIDER')), only_configure => 1);

    die 'Terraform deployment FAILED. Check "qesap*" logs for details.'
      if (qesap_execute(cmd => 'terraform', timeout => 3600, verbose => 1, cmd_options => "-w $workspace"));
    $provider->terraform_applied(1);
    my $instances = create_instance_data($provider);
    foreach my $instance (@$instances) {
        record_info 'Instance', join(' ', 'IP: ', $instance->public_ip, 'Name: ', $instance->instance_id);
        $self->{my_instance} = $instance;
        my $expected_hostname = $instance->{instance_id};
        $instance->wait_for_ssh();
        # Does not fail for some reason.
        my $real_hostname = $instance->run_ssh_command(cmd => 'hostname', username => 'cloudadmin');
        # We expect hostnames reported by terraform to match the actual hostnames in Azure and GCE
        die "Expected hostname $expected_hostname is different than actual hostname [$real_hostname]"
          if ((is_azure || is_gce) && ($expected_hostname ne $real_hostname));
    }

    $self->{instances} = $run_args->{instances} = $instances;
    $self->{instance} = $run_args->{my_instance} = $run_args->{instances}[0];
    $self->{provider} = $run_args->{my_provider} = $provider;    # Required for cleanup
    record_info('Deployment OK',);
    return 1;
}

sub post_fail_hook {
    my ($self, $run_args) = @_;
    qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}

1;
