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
use strict;
use warnings;
use testapi;
use Mojo::File 'path';
use publiccloud::utils;
use qesapdeployment;
use sles4sap_publiccloud;
use serial_terminal 'select_serial_terminal';

our $ha_enabled = set_var_output("HA_CLUSTER", "0") =~ /false|0/i ? 0 : 1;

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

    Detects HANA/HA scenario from openQA variables and creates "ansible: create:" section in config.yaml file.

=cut

sub create_playbook_section {
    # Cluster related setup
    my @playbook_list;
    my @hana_playbook_list = (
        "pre-cluster.yaml", "sap-hana-preconfigure.yaml -e use_sapconf=" . set_var_output("USE_SAPCONF", "true"),
        "cluster_sbd_prep.yaml", "sap-hana-storage.yaml",
        "sap-hana-download-media.yaml", "sap-hana-install.yaml",
        "sap-hana-system-replication.yaml", "sap-hana-system-replication-hooks.yaml",
        "sap-hana-cluster.yaml"
    );

    # Add registration module - "QESAP_SCC_NO_REGISTER" skips scc registration via ansible
    unless (get_var("QESAP_SCC_NO_REGISTER")) {
        my $reg_playbook = "registration.yaml -e reg_code=" . get_required_var("SCC_REGCODE_SLES4SAP") . " -e email_address=''";
        push(@playbook_list, $reg_playbook);
    }

    if ($ha_enabled == 1) {
        push(@playbook_list, @hana_playbook_list);
    }
    return (\@playbook_list);
}

=head2 create_ansible_playbook_list

    Detects HANA/HA scenario from openQA variables and creates "ansible: create:" section in config.yaml file.

=cut

sub create_hana_vars_section {
    # Cluster related setup
    my %hana_vars;
    if ($ha_enabled == 1) {
        $hana_vars{sap_hana_install_software_directory} = get_required_var("HANA_MEDIA");
        $hana_vars{sap_hana_install_master_password} = get_required_var("_HANA_MASTER_PW");
        $hana_vars{sap_hana_install_sid} = get_required_var("INSTANCE_SID");
        $hana_vars{sap_hana_install_instance_number} = get_required_var("INSTANCE_ID");
        $hana_vars{sap_domain} = get_var("SAP_DOMAIN", "qesap.example.com");
        $hana_vars{primary_site} = get_var("HANA_PRIMARY_SITE", "site_a");
        $hana_vars{secondary_site} = get_var("HANA_SECONDARY_SITE", "site_b");
        set_var("SAP_SIDADM", lc(get_var("INSTANCE_SID") . "adm"));
    }
    return (\%hana_vars);
}

sub run {
    my ($self, $run_args) = @_;
    select_serial_terminal();

    # Collect OpenQA variables and default values
    set_var_output("NODE_COUNT", 1) if $ha_enabled == 0;
    set_var_output("HANA_OS_MAJOR_VERSION", (split("-", get_var("VERSION")))[0]);
    # Cluster needs at least 2 nodes
    die("HA cluster needs at least 2 nodes. Check 'NODE_COUNT' parameter.") if $ha_enabled && get_var("NODE_COUNT") <= 1;

    get_required_var("PUBLIC_CLOUD_INSTANCE_TYPE");
    set_var("FENCING_MECHANISM", "native") if $ha_enabled == 0;

    my $provider = $self->provider_factory();
    set_var("SLE_IMAGE", $provider->get_image_id());
    my $ansible_playbooks = create_playbook_section();
    my $ansible_hana_vars = create_hana_vars_section();

    # Prepare QESAP deplyoment
    qesap_prepare_env(provider => lc(get_required_var('PUBLIC_CLOUD_PROVIDER')));
    qesap_create_ansible_section(ansible_section => 'create', section_content => $ansible_playbooks) if @$ansible_playbooks;
    qesap_create_ansible_section(ansible_section => 'hana_vars', section_content => $ansible_hana_vars) if %$ansible_hana_vars;

    # Regenerate config files (This workaround will be replaced with full yaml generator)
    qesap_prepare_env(provider => lc(get_required_var('PUBLIC_CLOUD_PROVIDER')), only_configure => 1);
    # This tells "create_instances" to skip the deployment setup related to old ha-sap-terraform-deployment project
    $provider->{terraform_env_prepared} = 1;
    my @instances = $provider->create_instances(check_connectivity => 0);
    my @instances_export;

    foreach my $instance (@instances) {
        $self->{my_instance} = $instance;
        my $expected_hostname = $instance->{instance_id};
        push(@instances_export, $instance);
        $instance->wait_for_ssh();
        # Does not fail for some reason.
        my $real_hostname = $instance->run_ssh_command(cmd => "hostname", username => "cloudadmin");
        # We expect hostnames reported by terraform to match the actual hostnames in Azure and GCE
        die "Expected hostname $expected_hostname is different than actual hostname [$real_hostname]"
          if ((is_azure || is_gce) && ($expected_hostname ne $real_hostname));
    }

    $self->{instances} = $run_args->{instances} = \@instances_export;
    $self->{instance} = $run_args->{my_instance} = $run_args->{instances}[0];
    $self->{provider} = $run_args->{my_provider} = $provider;    # Required for cleanup
    record_info("Deployment OK",);
    return 1;
}

1;
