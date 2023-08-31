# SUSE's openQA tests
#
# Copyright 2022-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test deploy a helm chart in a k3s
# - install k3s, kubectl and helm
# - test helm install
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
    ensure_ca_certificates_suse_installed();
    install_k3s();
    install_kubectl();
    install_helm();

    my $rmt_helm = get_var('RMTTEST_CHART', 'https://github.com/SUSE/helm-charts/archive/refs/heads/main.tar.gz');
    # pull in the testsuite
    assert_script_run("curl -sSL $rmt_helm | tar -zxf -");
    my $rmt_config = get_var('RMTTEST_CONFIG', 'https://gitlab.suse.de/QA-APAC-I/testing/-/raw/master/data/rmtcontainer/myvalue.yaml');
    assert_script_run("curl -sSLO $rmt_config");
    my $prefix = "registry.suse.de/suse/sle-15-sp5/update/cr/totest/images/suse";
    my $set_options = "--set app.image.repository=$prefix/rmt-server --set app.image.tag=latest";
    $set_options .= " --set app.init.image.repository=$prefix/rmt-mariadb-client --set app.init.image.tag=latest";
    $set_options .= " --set db.image.repository=$prefix/rmt-mariadb --set db.image.tag=latest";
    $set_options .= " --set front.image.repository=$prefix/rmt-nginx --set front.image.tag=latest";
    my $helm_options = "--debug";
    assert_script_run("helm install $set_options rmt ./helm-charts-main/rmt-helm -f myvalue.yaml $helm_options");
    assert_script_run("helm list");
    sleep 20;
    my @out = split(' ', script_output("kubectl get pods | grep rmt-app"));
    my $counter = 0;
    while ($counter++ < 50) {
        sleep 20;
        my $logs = script_output("kubectl logs $out[0]", proceed_on_failure => 1);
        last if ($logs =~ /All repositories have already been enabled/);
    }
    assert_script_run("kubectl exec $out[0] -- rmt-cli repos list");
    assert_script_run('test $(kubectl get pods --field-selector=status.phase=Running | grep -c rmt) -eq 3');
}

sub post_fail_hook {
    my ($self) = @_;
    assert_script_run('tar -capf /tmp/containers-logs.tar.xz /var/log/pods $(find /var/lib/rancher/k3s -name \*.log -name \*.toml)');
    upload_logs("/tmp/containers-logs.tar.xz");
    script_run("helm delete rmt");
    uninstall_k3s() if $self->{is_k3s};
}

sub test_flags {
    return {milestone => 1};
}

1;
