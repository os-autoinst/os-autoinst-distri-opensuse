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
use utils;
use serial_terminal 'select_serial_terminal';
use containers::k8s;

sub run {
    my ($self) = @_;

    select_serial_terminal;
    systemctl 'stop firewalld';
    install_k3s();
    install_kubectl();
    install_helm();

    my $rmt_helm = get_var('RMTTEST_REPO', 'https://github.com/SUSE/helm-charts/archive/refs/heads/main.zip');
    # pull in the testsuite
    assert_script_run("wget --quiet --no-check-certificate " . $rmt_helm);
    assert_script_run("unzip main.zip");
    my $myvalue = get_var('MY_VALUE', 'https://gitlab.suse.de/QA-APAC-I/testing/-/raw/master/data/rmtcontainer/myvalue.yaml');
    assert_script_run("wget --no-check-certificate " . $myvalue);
    assert_script_run("helm install rmt ./helm-charts-main/rmt-helm -f myvalue.yaml");
    assert_script_run("helm list");
    my @out = split(' ', script_output("kubectl get pods | grep rmt-app"));
    my $counter = 0;
    while ($counter++ < 50) {
        sleep 20;
        my $logs = script_output("kubectl logs $out[0]", proceed_on_failure => 1);
        last if ($logs =~ /All repositories have already been enabled/);
    }
    assert_script_run("kubectl exec $out[0] rmt-cli repos list");
}

sub post_fail_hook {
    my ($self) = @_;
    script_run("helm delete rmt");
    uninstall_k3s() if $self->{is_k3s};
}

sub test_flags {
    return {milestone => 1};
}

1;
