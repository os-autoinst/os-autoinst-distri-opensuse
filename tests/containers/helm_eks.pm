# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test deploy a helm chart using a Public Cloud Kubernetes environment EKS
# - install kubectl and helm
# - test helm repo add, update, search and show all
# - add bitnami repo
# - test helm install with apache helm chart
# - test helm list
# - check the correct deployment of the helm chart
# - cleanup system (helm)
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils qw(zypper_call script_retry);
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product get_addon_fullname);
use mmapi 'get_current_job_id';
use containers::k8s;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;
    $self->{deployment_name} = "apache-" . get_current_job_id();
    my $chart = "bitnami/apache";

    install_kubectl();
    install_helm();
    add_suseconnect_product(get_addon_fullname('pcm')) if (is_sle);
    zypper_call("in -y jq aws-cli");

    # Check versions
    record_info('Helm version', script_output("helm version"));
    record_info('AWS', script_output('aws --version'));

    # Connection to AWS
    my $provider = $self->provider_factory(service => 'EKS');
    $self->{provider} = $provider;

    # Access to Cluster
    record_info('Kubectl version', script_output("kubectl version"));
    assert_script_run("cat \$HOME/.kube/config");
    assert_script_run("kubectl get nodes");

    # Add repo, search and show values
    assert_script_run("helm repo add bitnami https://charts.bitnami.com/bitnami");
    assert_script_run("helm repo update");
    assert_script_run("helm search repo apache");
    assert_script_run("helm show all $chart");

    # Install apache
    assert_script_run("helm install $self->{deployment_name} $chart");
    assert_script_run("helm list");

    # Wait for deployment
    assert_script_run("kubectl rollout status deployment/$self->{deployment_name}");
    assert_script_run("kubectl describe deployment/$self->{deployment_name}");
    assert_script_run("kubectl get pods | grep $self->{deployment_name}");
    assert_script_run("kubectl describe services/$self->{deployment_name}");

    # Test
    enter_cmd("kubectl port-forward services/$self->{deployment_name} 10001:80 &");
    script_retry("curl http://localhost:10001", delay => 30, retry => 5);

    # Destroy the chart
    assert_script_run("helm delete $self->{deployment_name}");
}

sub post_fail_hook {
    my ($self) = @_;
    script_run("helm delete $self->{deployment_name}");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
