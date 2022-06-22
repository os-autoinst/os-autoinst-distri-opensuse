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
use utils qw(zypper_call script_retry);
use version_utils qw(is_sle);
use mmapi 'get_current_job_id';
use registration qw(add_suseconnect_product get_addon_fullname);
use containers::k8s;
use publiccloud::utils qw(gcloud_install);

sub run {
    my ($self, $run_args) = @_;

    # We either test various cloud clusters or local k3s
    my $k8s_backend = shift(@{$run_args->{backends}});

    record_info("K8s engine", $k8s_backend);

    my $is_k3s = $k8s_backend eq 'K3S';
    $self->{is_k3s} = $is_k3s;

    $self->select_serial_terminal;
    $self->{deployment_name} = "apache-" . get_current_job_id();
    my $chart = "bitnami/apache";

    record_info("Chart name", $chart);

    if ($is_k3s) {
        install_k3s();
    }
    else {
        install_kubectl();

        my $provider;

        # Configure the public cloud kubernetes
        if ($k8s_backend eq "EKS") {
            add_suseconnect_product(get_addon_fullname('pcm')) if is_sle;
            zypper_call("in jq aws-cli", timeout => 300);

            $provider = publiccloud::eks->new();
        }
        elsif ($k8s_backend eq 'AKS') {
            add_suseconnect_product(get_addon_fullname('pcm'),
                (is_sle('=12-sp5') ? '12' : undef));
            add_suseconnect_product(get_addon_fullname('phub'))
              if is_sle('=12-sp5');
            zypper_call('in jq azure-cli', timeout => 300);

            $provider = publiccloud::aks->new();
        }
        elsif ($k8s_backend eq 'GKE') {
            add_suseconnect_product(get_addon_fullname('pcm')) if is_sle;
            gcloud_install();

            # package needed by init():
            (is_sle('=15-SP4'))
              ? zypper_call("in chrony", timeout => 300)
              : zypper_call("in ntp", timeout => 300);

            $provider = publiccloud::gke->new();
        }
        else {
            die('Unknown service given');
        }

        $provider->init();
    }

    install_helm();

    # Add repo, search and show values
    assert_script_run(
        "helm repo add bitnami https://charts.bitnami.com/bitnami", 180);
    assert_script_run("helm repo update", 180);
    assert_script_run("helm search repo apache");
    assert_script_run("helm show all $chart");

    # Install apache
    assert_script_run("helm install $self->{deployment_name} $chart");
    assert_script_run("helm list");

    # Wait for deployment
    script_retry(
        "kubectl rollout status deployment/$self->{deployment_name}",
        delay => 30,
        retry => 10
    );
    assert_script_run("kubectl describe deployment/$self->{deployment_name}");
    assert_script_run("kubectl get pods | grep $self->{deployment_name}");
    assert_script_run("kubectl describe services/$self->{deployment_name}");

    # Test
    my $port = int(rand(100)) + 10000;
    enter_cmd(
        "kubectl port-forward  services/$self->{deployment_name} $port:80 &");
    script_retry("curl http://localhost:$port", delay => 30, retry => 5);

    # Destroy the chart and k3s
    assert_script_run("helm delete $self->{deployment_name}");
    uninstall_k3s() if $is_k3s;
}

sub post_fail_hook {
    my ($self) = @_;
    script_run("helm delete $self->{deployment_name}");
    uninstall_k3s() if $self->{is_k3s};
}

sub test_flags {
    return {milestone => 1};
}

1;
