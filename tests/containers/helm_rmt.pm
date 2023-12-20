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
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use File::Basename qw(dirname);
use testapi;
use utils;
use version_utils qw(get_os_release is_sle);
use serial_terminal qw(select_serial_terminal);
use Utils::Architectures qw(is_ppc64le);
use containers::k8s;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my ($version, $sp, $host_distri) = get_os_release;
    # Skip HELM tests on SLES <15-SP3 and on PPC, where k3s is not available
    return if (!($host_distri == "sles" && $version == 15 && $sp >= 3) || is_ppc64le || check_var('CONTAINER_RUNTIMES', 'k8s'));

    systemctl 'stop firewalld';
    ensure_ca_certificates_suse_installed();
    install_k3s();
    install_kubectl();
    install_helm();

    my $curl_options = "-sSL --retry 3 --retry-delay 30";

    my $helm_chart = get_var('HELM_CHART', 'https://github.com/SUSE/helm-charts/archive/refs/heads/main.tar.gz');
    # pull in the testsuite
    assert_script_run("curl $curl_options $helm_chart | tar -zxf -");
    my $helm_values = get_var('HELM_CONFIG', 'https://gitlab.suse.de/QA-APAC-I/testing/-/raw/master/data/rmtcontainer/myvalue.yaml');
    assert_script_run("curl $curl_options -O $helm_values");
    my ($repository, $tag) = split(':', get_required_var('CONTAINER_IMAGE_TO_TEST'), 2);
    my $set_options = "--set app.image.repository=$repository --set app.image.tag=$tag";
    my $helm_options = "--debug";
    assert_script_run("helm install $set_options rmt ./helm-charts-main/rmt-helm -f myvalue.yaml $helm_options");
    assert_script_run("helm list");
    sleep 20;    # Wait until images are downloaded
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
