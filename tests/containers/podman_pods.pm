# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test podman pods functionality
# - Use data/containers/hello-kubic.yaml to run pods
# - Confirm 1 pod is spawned
# - Clean up pods using hello-kubic.yaml
# Maintainer: Richard Brown <rbrown@suse.com>

use Mojo::Base 'containers::basetest';
use testapi;
use utils qw(script_retry);
use containers::utils qw(check_min_runtime_version);
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle is_opensuse is_staging);
use containers::k8s qw(install_k3s uninstall_k3s);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $podman = $self->containers_factory('podman');
    $self->{podman} = $podman;

    record_info('Prep', 'Get kube yaml');
    assert_script_run('curl ' . data_url('containers/hello-kubic.yaml') . ' -o hello-kubic.yaml');

    record_info('Test', 'Create hello-kubic pod');
    assert_script_run('podman play kube hello-kubic.yaml');

    record_info('Test', 'Confirm pods are running');
    record_info('pod ps', script_output('podman pod ps'));
    assert_script_run('podman pod ps | grep "Running" | wc -l | grep -q 1');

    record_info('Test', 'Killing one pod');
    assert_script_run('podman pod stop $(podman pod ps -q | head -n1)');

    record_info('Test', 'Confirm one pod has been killed');
    assert_script_run('podman pod ps | grep "Exited" | wc -l | grep -q 1');

    if (is_sle('15-SP3+') || is_opensuse()) {
        record_info('Cleanup', 'Stop pods');
        assert_script_run('podman play kube --down hello-kubic.yaml');
    }

    unless (!check_min_runtime_version('4.4.2')) {
        # Kube generate
        record_info('Test', 'Generate the yaml from a pod');
        assert_script_run('podman pod create testing-pod');
        my $image = "registry.suse.com/bci/bci-busybox:latest";
        script_retry("podman pull $image", timeout => 300, delay => 60, retry => 3);
        assert_script_run("podman container create --pod testing-pod --name container $image sh -c \"sleep 3600\"");
        assert_script_run("podman kube generate testing-pod | tee pod.yaml");
        assert_script_run("grep 'image: $image' pod.yaml");
        assert_script_run("podman pod rm testing-pod");

        record_info('Test', 'Test the pod yaml creates a pod');
        assert_script_run('podman play kube pod.yaml');
        record_info('Test', 'Confirm pod is running');
        record_info('pod ps', script_output('podman pod ps'));
        validate_script_output('podman pod ps', sub { m/testing-pod/ });
        validate_script_output('podman ps', sub { m/testing-pod-container/ });

        record_info('Test', 'Removing one pod');
        assert_script_run('podman pod rm -f testing-pod');

        # kube play
        record_info('Test', 'kube play');
        assert_script_run('podman kube play pod.yaml');
        validate_script_output('podman pod ps', sub { m/testing-pod/ });
        validate_script_output('podman ps', sub { m/testing-pod-container/ });

        # kube down
        record_info('Test', 'kube down');
        assert_script_run('podman kube down pod.yaml');
        validate_script_output('podman pod ps', sub { !m/testing-pod/ });
        validate_script_output('podman ps', sub { !m/testing-pod-container/ });

        # Staging does not have access to repositories, only to DVD
        if (check_min_runtime_version('4.4.0') && !is_staging) {
            install_k3s();
            record_info('Test', 'kube apply');
            assert_script_run('podman kube apply --kubeconfig ~/.kube/config -f pod.yaml');
            assert_script_run('kubectl wait --timeout=240s --for=condition=Ready pod/testing-pod', timeout => 260);
            validate_script_output('kubectl exec testing-pod -- cat /etc/os-release', sub { m/SUSE Linux Enterprise Server/ });
        }
    }
}

sub cleanup {
    my ($self) = @_;
    $self->{podman}->cleanup_system_host();
    # Staging does not have access to repositories, only to DVD
    uninstall_k3s() if (check_min_runtime_version('4.4.0') && !is_staging);
}

sub post_run_hook {
    my ($self) = @_;
    $self->cleanup();
}

sub post_fail_hook {
    my ($self) = @_;
    $self->cleanup();
}

1;
