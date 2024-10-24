# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Basic aistack test

# Summary: This test performs the following actions
#  - Create a VM in EC2 using SLE-Micro-BYOS later than 6.0 version
#  - Install the required dependencies to install the aistack helm chart
#  - Test access to OpenWebUI and run integration tests with Ollama and MilvusDB
# Maintainer: Yogalakshmi Arunachalam <yarunachalam@suse.com>
#

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use publiccloud::utils qw(is_byos registercloudguest register_openstack);
use publiccloud::ssh_interactive 'select_host_console';
use transactional;
use strict;
use warnings;
use utils;
use publiccloud::utils;
use transactional qw(process_reboot trup_install trup_shell);
use File::Basename;
use version_utils;
use Data::Dumper;

sub install_dependency_package {
    my ($instance, $rke2_url, $kubectl_url, $helm_url) = @_;

    my $runtime = get_required_var('PUBLIC_CLOUD_AISTACK_DEP_PKG');
    my $tr_install_cmd = "";

    for (split(',\s*', $runtime)) {
        my $package = $_;
        my $pkg_status = script_run("rpm -q $package");
        record_info("Package status $pkg_status");

        if ($pkg_status == 0) {
            record_info("$package is already installed");
        } else {
            record_info("$package is not installed, installing now...");
            if ($package eq "rke2-server") {
                $tr_install_cmd .= "curl -sfL $rke2_url | sh; ";
            } elsif ($package eq "kubectl") {
                $tr_install_cmd .= "curl -LO $kubectl_url; ";
                $tr_install_cmd .= "chmod +x ./kubectl; ";
                $tr_install_cmd .= "mkdir -p ~/bin; ";
                $tr_install_cmd .= "mv ./kubectl ~/bin/kubectl; ";
                $tr_install_cmd .= "echo 'export PATH=\$PATH:\$HOME/bin' >> ~/.bashrc; ";
                $tr_install_cmd .= "source ~/.bashrc; ";
                $tr_install_cmd .= "kubectl version --client; ";
            } elsif ($package eq "helm") {
                $tr_install_cmd .= "curl $helm_url; ";
            } elsif ($package eq "docker") {
                $tr_install_cmd .= "sudo zypper install -n docker; ";
            } else {
                $tr_install_cmd .= "$package; ";
            }
            record_info("Prepared installation command for $package.");
        }
    }
    # Execute all commands with trup_shell
    if ($tr_install_cmd) {
        record_info("Executing $tr_install_cmd");
        trup_shell($tr_install_cmd);
        exit_trup_shell_and_reboot();
    }

    for (split(',\s*', $runtime)) {
        my $ins_package = $_;
        if ((script_run("rpm -q $ins_package") == 0) && ($ins_package eq 'rke2-server' || $ins_package eq 'docker')) {
            record_info("rke2-server is installed. Enable and start server");
            $instance->assert_script_run("sudo systemctl enable $ins_package", timeout => 100);
            $instance->assert_script_run("sudo systemctl start $ins_package", timeout => 100);
            $instance->assert_script_run("sudo systemctl status $ins_package", timeout => 100);
        } else {
            record_info("$ins_package is not installed.");
        }
    }
}

sub install_aistack_chart {
    my ($instance, $cert_repo, $ing_repo) = @_;
    record_info('Install AISTACK helm charts');

    # Add cert-manager repo,install and show values
    $instance->assert_script_run("helm repo add $cert_repo", 180);
    $instance->assert_script_run("helm repo update", 180);
    $instance->assert_script_run("helm install cert-manager jetstack/cert-manager --namespace cert-manger --create-namespace --version v1.15.2 --set crds.enabled=true");
    $instance->assert_script_run("helm list");
    $instance->assert_script_run("kubectl get pods --namespace cert-manager");

    # Add ingress repo,install and show values
    $instance->assert_script_run("helm repo add $ing_repo", 180);
    $instance->assert_script_run("helm repo update", 180);
    $instance->assert_script_run("helm search repo ingress-nginx -l", 180);
    $instance->assert_script_run("helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --set controller.service.type=LoadBalancer --version 4.11.1 --create-namespace");
    $instance->assert_script_run("helm list");
    $instance->assert_script_run("kubectl get pods --namespace ingress-nginx");

    # Access to Application collection registery
    # Get docker username and password
    $instance->assert_script_run("kubectl create ns suse-private-ai");
    $instance->assert_script_run("kubectl create secret docker-registry application-collection --docker-server=dp.apps.rancher.io --docker-username=<application_collection_user_email> --docker-password=<application_collection_user_token> -n suse-private-ai");

    # Add suse-private-ai install
    $instance->assert_script_run("helm upgrade --install suse-private-ai --namespace suse-private-ai --create-namespace");
    $instance->assert_script_run("helm list");
    $instance->assert_script_run("kubectl get pods --namespace suse-private-ai");
    $instance->assert_script_run("kubectl get all --namespace suse-private-ai");
}

sub run {
    my ($self, $args) = @_;

    # Required tools
    my $ins_rke2 = get_var('RKE2_URL');
    my $ins_kubectl = get_var('KUBECTL_URL');
    my $ins_helm = get_var('HELM_URL');
    my $helm_certs_repo = get_var('HELM_CERTS');
    my $helm_ing_repo = get_var('HELM_INGRESS');


    # Initial credentials from openwebui
    # my $openwebui_hostname = get_var('OPENWEBUI_HOSTNAME');
    set_var('OPENWEBUI_ADMIN', 'admin');
    set_var('OPENWEBUI_PASSWD', 'WelcomeToAI');

    my $instance = $self->{my_instance} = $args->{my_instance};
    my $provider = $self->{provider} = $args->{my_provider};

    # Install dependency package
    install_dependency_package($instance, $ins_rke2, $ins_kubectl, $ins_helm);
    install_aistack_chart($instance, $helm_certs_repo, $helm_ing_repo);

    # OpenWebUI Integration test
    #test_openwebui_interaction();
    record_info('End of AISTACK_BASIC');
}

1;
