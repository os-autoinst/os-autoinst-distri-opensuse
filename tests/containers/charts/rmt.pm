# SUSE's openQA tests
#
# Copyright 2022-2025 SUSE LLC
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

use Mojo::Base 'containers::basetest';
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
    return if (!($host_distri == "sles" && $version == 15 && $sp >= 3) || is_ppc64le);
    die "helm tests only work on k3s" unless (check_var('CONTAINER_RUNTIMES', 'k3s'));

    my $helm_chart = get_required_var('HELM_CHART');

    install_kubectl();
    install_helm();

    # Pull helm chart, if it is a http file
    if ($helm_chart =~ m!^http(s?)://!) {
        my ($url, $path) = split(/#/, $helm_chart, 2);    # split extracted folder path, if present
        assert_script_run("curl -sSL --retry 3 --retry-delay 30 $url | tar -zxf -");
        $helm_chart = $path ? "./$path" : ".";
    }
    my $helm_values = get_var('HELM_CONFIG');
    assert_script_run("curl -sSL --retry 3 --retry-delay 30 -o myvalue.yaml $helm_values") if ($helm_values);
    my $set_options = "";
    if (my $image = get_var('CONTAINER_IMAGE_TO_TEST')) {
        my ($repository, $tag) = split(':', $image, 2);
        $set_options = "--set app.image.repository=$repository --set app.image.tag=$tag";
    }
    my $helm_options = "--debug";
    $helm_options = "-f myvalue.yaml $helm_options" if ($helm_values);
    script_retry("helm pull $helm_chart", timeout => 300, retry => 6, delay => 60) if ($helm_chart =~ m!^oci://!);
    assert_script_run("helm install $set_options rmt $helm_chart $helm_options", timeout => 300);
    assert_script_run("helm list");
    validate_script_output_retry("kubectl get pods", qr/rmt-app/, retry => 10, delay => 30, timeout => 120, fail_message => "rmt-app didn't became ready");
    my @rmts = split(' ', script_output("kubectl get pods | grep rmt-app"));
    my $rmtapp = $rmts[0];
    validate_script_output_retry("kubectl logs $rmtapp", sub { m/All repositories have already been enabled/ }, retry => 30, timeout => 60, delay => 60);
    assert_script_run("kubectl exec $rmtapp -- rmt-cli repos list");
    assert_script_run('test $(kubectl get pods --field-selector=status.phase=Running | grep -c rmt) -eq 3');
}

sub post_fail_hook {
    my ($self) = @_;
    script_run('tar -capf /tmp/containers-logs.tar.xz /var/log/pods $(find /var/lib/rancher/k3s -name \*.log -name \*.toml)');
    upload_logs("/tmp/containers-logs.tar.xz");
    script_run("helm delete rmt");
}

sub test_flags {
    return {milestone => 1};
}

1;
