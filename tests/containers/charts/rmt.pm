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

use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use File::Basename qw(dirname);
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils;
use containers::helm;
use containers::k8s qw(install_kubectl install_helm);

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $helm_chart = get_required_var('HELM_CHART');
    my $helm_values = get_var('HELM_CONFIG');

    return unless (helm_is_supported());

    install_kubectl();
    install_helm();

    helm_install_chart($helm_chart, $helm_values, "rmt");

    validate_script_output_retry("kubectl get pods", qr/rmt-app/, retry => 10, delay => 30, timeout => 120, fail_message => "rmt-app didn't become ready");
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
