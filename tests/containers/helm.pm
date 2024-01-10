# SUSE's openQA tests
#
# Copyright 2022-2023 SUSE LLC
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
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call script_retry script_output_retry);
use version_utils qw(is_sle);
use mmapi 'get_current_job_id';
use registration qw(add_suseconnect_product get_addon_fullname);
use containers::k8s;
use publiccloud::utils qw(gcloud_install);

sub run {
    my ($self, $run_args) = @_;
    my $job_id = get_current_job_id();

    # We either test various cloud clusters or local k3s
    my $k8s_backend = shift(@{$run_args->{backends}});

    record_info("K8s engine", $k8s_backend);

    my $is_k3s = $k8s_backend eq 'K3S';
    $self->{is_k3s} = $is_k3s;

    select_serial_terminal;
    my $chart = "bitnami/apache";

    record_info("Chart name", $chart);

    if ($is_k3s) {
        install_k3s();
    }
    else {
        install_kubectl();

        my $provider;

        # Configure the public cloud kubernetes
        if ($k8s_backend eq "EC2") {
            add_suseconnect_product(get_addon_fullname('pcm')) if is_sle;
            zypper_call("in jq aws-cli", timeout => 300);

            # publiccloud::aws_client needs to demand PUBLIC_CLOUD_REGION due to other places where
            # we don't want to have defaults and want tests to fail when region is not defined
            # so this is workaround to keep variable required for publiccloud::aws_client
            # but not for cases where we using publiccloud::ecr which also must to init publiccloud::aws_client
            # and in this case we CAN NOT define it on job level because publiccloud::aws_client
            # will be initialized together with publiccloud::azure_client so same variable will need
            # to have two different values
            set_var('PUBLIC_CLOUD_REGION', 'eu-central-1') unless get_var('PUBLIC_CLOUD_REGION');

            $provider = publiccloud::eks->new();
        }
        elsif ($k8s_backend eq 'AZURE') {
            add_suseconnect_product(get_addon_fullname('pcm'),
                (is_sle('=12-sp5') ? '12' : undef));
            add_suseconnect_product(get_addon_fullname('phub'))
              if is_sle('=12-sp5');
            zypper_call('in jq azure-cli', timeout => 300);

            # publiccloud::azure_client needs to demand PUBLIC_CLOUD_REGION due to other places where
            # we don't want to have defaults and want tests to fail when region is not defined
            # so this is workaround to keep variable required for publiccloud::azure_client
            # but not for cases where we using publiccloud::acr which also must to init publiccloud::azure_client
            # and in this case we CAN NOT define it on job level because publiccloud::aws_client
            # will be initialized together with publiccloud::azure_client so same variable will need
            # to have two different values
            set_var('PUBLIC_CLOUD_REGION', 'westeurope') unless get_var('PUBLIC_CLOUD_REGION');

            $provider = publiccloud::aks->new();
        }
        elsif ($k8s_backend eq 'GCE') {
            add_suseconnect_product(get_addon_fullname('pcm')) if is_sle;
            gcloud_install();

            # package needed by init():
            my $pkg = is_sle('>=15') ? "in chrony" : "in ntp";
            zypper_call($pkg, timeout => 300);

            $provider = publiccloud::gke->new();
        }
        else {
            die('Unknown service given');
        }

        $provider->init();
    }

    install_helm();

    assert_script_run('curl --create-dir -vo ~/helm-test/Chart.yaml ' . data_url('containers/helm-test/') . 'Chart.yaml');
    assert_script_run('curl --create-dir -vo ~/helm-test/values.yaml ' . data_url('containers/helm-test/') . 'values.yaml');
    assert_script_run('curl --create-dir -vo ~/helm-test/templates/job.yaml ' . data_url('containers/helm-test/templates/') . 'job.yaml');
    assert_script_run('curl --create-dir -vo ~/helm-test/templates/NOTES.txt ' . data_url('containers/helm-test/templates/') . 'NOTES.txt');

    assert_script_run("kubectl create namespace helm-ns-$job_id");
    assert_script_run("kubectl config set-context --current --namespace=helm-ns-$job_id");

    assert_script_run("helm install helm-test-$job_id ~/helm-test/ --values ~/helm-test/values.yaml --set job_id=$job_id");
    assert_script_run("helm list");

    my $pod = script_output_retry('kubectl get pods -o name --no-headers=true | grep helm-test-$job_id', retry => 3, delay => 10);
    script_retry("kubectl logs $pod | grep 'SUSE'", retry => 12, delay => 15);
    assert_script_run("helm uninstall helm-test-$job_id");

    assert_script_run("kubectl config set-context --current --namespace=default");
    script_run("kubectl delete namespace helm-ns-$job_id");

    # Add repo, search and show values
    assert_script_run(
        "helm repo add bitnami https://charts.bitnami.com/bitnami", 180);
    assert_script_run("helm repo update", 180);
    assert_script_run("helm search repo apache");
    assert_script_run("helm show all $chart");

    uninstall_k3s() if $is_k3s;
}

sub post_fail_hook {
    my ($self) = @_;
    my $job_id = get_current_job_id();

    script_run("helm uninstall helm-test-$job_id");

    script_run("kubectl config set-context --current --namespace=default");
    script_run("kubectl delete namespace helm-ns-$job_id");

    uninstall_k3s() if $self->{is_k3s};
}

sub test_flags {
    return {milestone => 1};
}

1;
