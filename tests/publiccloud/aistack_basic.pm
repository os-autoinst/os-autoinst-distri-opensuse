# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Basic aistack test

# SUMMARY
# This test performs the following actions:
#  - Create a VM in EC2 using SLE-Micro-6-0-BYOS.x86_64-1.0.0-EC2-Build1.36.raw.xz
#  - Install the required dependencies to install the aistack helm chart and containers
#  - Test access to OpenWebUI and run integration tests with Ollama and MilvusDB
# MAINTAINER
# Yogalakshmi Arunachalam <yarunachalam@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use publiccloud::utils qw(is_byos registercloudguest register_openstack);
use publiccloud::ssh_interactive 'select_host_console';
use strict;
use warnings;
use utils;
use publiccloud::utils;
use File::Basename;

sub install_package {
    my ($instance, $package) = @_;

    record_info("Install $package",
        "Install package $package using transactional server and reboot");
    trup_install($package);

    $instance->ssh_assert_script_run("sudo systemctl start $package",
        timeout => 100);
    $instance->ssh_assert_script_run("sudo systemctl enable $package",
        timeout => 100);
    $instance->ssh_assert_script_run("sudo systemctl status $package",
        timeout => 100);
    record_info("Installed $package");
}

sub create_aistack {
    my ($instance, $rke2_url, $kubectl_url, $helm_url) = @_;

    # Install dependencies
    record_info('Refresh and update');
    $instance->ssh_assert_script_run('sudo zypper ref; sudo zypper -n up',
        timeout => 1000);
    sleep 90;    # Wait for zypper to be available

    install_package($instance, "curl");
    install_package($instance, "docker");

    # Install RKE2
    $instance->ssh_assert_script_run("curl -sfL $rke2_url | sh",
        timeout => 1000);
    $instance->ssh_assert_script_run('sudo systemctl enable rke2-server',
        timeout => 100);
    $instance->ssh_assert_script_run('sudo systemctl start rke2-server',
        timeout => 100);
    $instance->ssh_assert_script_run('sudo systemctl status rke2-server',
        timeout => 100);
    record_info('Installed RKE2');

    # Install kubectl
    $instance->ssh_assert_script_run("curl -LO $kubectl_url",
        timeout => 1000);
    $instance->ssh_assert_script_run('chmod +x ./kubectl', timeout => 100);
    $instance->ssh_assert_script_run('sudo mv ./kubectl /usr/local/bin/kubectl',
        timeout => 100);
    $instance->ssh_assert_script_run('kubectl version --client',
        timeout => 100);
    record_info('kubectl setup complete');

    # Install Helm
    $instance->ssh_assert_script_run("curl $helm_url | bash",
        timeout => 1000);
    record_info('Helm installation complete');
}

sub run {
    my ($self, $args) = @_;

    # Required tools
    my $ins_rke2 = get_var('RKE2_URL');
    my $ins_kubectl = get_var('KUBECTL_URL');
    my $ins_helm = get_var('HELM_URL');

    # Create AWS instance
    my $provider;
    my $instance;

    #credentials from openwebui
    #my $admin_username = get_var('OPENWEBUI_ADMIN');
    #my $admin_password = get_var('OPENWEBUI_PASSWD');
    #my $openwebui_hostname = get_var('OPENWEBUI_HOSTNAME');

    select_host_console();

    my $aws_ai_test =
      get_var('PUBLIC_CLOUD_INSTANCE_FOR_AWS_AI', 'basic_sanity');
    if ($aws_ai_test) {
        $instance = $self->{my_instance} = $args->{my_instance};
        $provider = $self->{provider} =
          $args->{my_provider};    # Required for cleanup
    }
    else {
        $provider = $self->{provider} =
          $self->provider_factory();    # Required for cleanup
        $instance = $self->{my_instance} = $provider->create_instance(
            check_guestregister => is_openstack ? 0 : 1);
    }

    registercloudguest($instance) if is_byos();
    registercloudguest($instance) if (is_byos() && !$aws_ai_test);

    # Create AI stack
    create_aistack($instance, $ins_rke2, $ins_kubectl, $ins_helm);

    # Validate OpenWebUI
    #validate_openwebui($admin_username, $admin_password, $openwebui_hostname);
    # Verify Ollama api endpoint
    #verify_api_endpoint();
    # Milvus DB Test
    #milvus_db_test();
    # Milvus DB Test
    #milvus_db_test();
    # OpenWebUI Integration test
    #test_openwebui_interaction();
}

1;
