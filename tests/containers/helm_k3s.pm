# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test deploy a helm chart in a k3s
# - install k3s, kubectl and helm
# - test helm repo add, update, search and show all
# - add bitnami repo
# - test helm install with apache helm chart
# - test helm list
# - check the correct deployment of the helm chart
# - cleanup system (helm and k3s)
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils qw(script_retry);
use mmapi 'get_current_job_id';
use containers::k8s;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;
    $self->{deployment_name} = "apache-" . get_current_job_id();
    my $chart = "bitnami/apache";

    install_k3s();
    install_kubectl();
    install_helm();

    # Add repo, search and show values
    assert_script_run("helm repo add bitnami https://charts.bitnami.com/bitnami");
    assert_script_run("helm repo update");
    assert_script_run("helm search repo apache");
    assert_script_run("helm show all $chart");

    # Install apache
    assert_script_run("helm install $self->{deployment_name} $chart");
    assert_script_run("helm list");

    # Wait for deployment
    script_retry("kubectl rollout status deployment/$self->{deployment_name}", delay => 30, retry => 5);
    assert_script_run("kubectl describe deployment/$self->{deployment_name}");
    assert_script_run("kubectl get pods | grep $self->{deployment_name}");
    assert_script_run("kubectl describe services/$self->{deployment_name}");

    # Test
    enter_cmd("kubectl port-forward  services/$self->{deployment_name} 10002:80 &");
    script_retry("curl http://localhost:10002", delay => 30, retry => 5);

    # Destroy the chart and k3s
    assert_script_run("helm delete $self->{deployment_name}");
    uninstall_k3s();
}

sub post_fail_hook {
    my ($self) = @_;
    script_run("helm delete $self->{deployment_name}");
    uninstall_k3s();
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
