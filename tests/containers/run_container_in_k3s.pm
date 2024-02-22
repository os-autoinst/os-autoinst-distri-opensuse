# SUSE's openQA tests
#
# Copyright 2022-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Installs local k3s locally and executes a test
# to be sure this is working properly
#
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use publiccloud::utils;
use containers::utils qw(check_min_runtime_version);
use Utils::Architectures qw(is_ppc64le);
use containers::k8s qw(install_k3s uninstall_k3s apply_manifest wait_for_k8s_job_complete find_pods validate_pod_log);

sub prepare_pod_yaml {
    record_info('Prep', 'Generate the yaml from a pod');
    my $image = "registry.suse.com/bci/bci-busybox:latest";
    script_retry("podman pull $image", timeout => 300, delay => 60, retry => 3);
    assert_script_run("podman container create -t --pod new:testing-pod $image");
    assert_script_run("podman kube generate testing-pod | tee pod.yaml");
    assert_script_run("grep 'image: $image' pod.yaml");
    assert_script_run("podman pod rm testing-pod");
}

sub run {
    select_serial_terminal;

    my $image = get_var("CONTAINER_IMAGE_TO_TEST", "registry.suse.com/bci/bci-base:latest");

    install_k3s();

    my $cmd = '"cat", "/etc/os-release"';
    my $job_name = "test";

    assert_script_run("curl -O " . data_url("containers/k8s_job_manifest.yaml"));
    file_content_replace("k8s_job_manifest.yaml", JOB_NAME => $job_name, IMAGE => $image, CMD => $cmd);
    assert_script_run("kubectl apply -f k8s_job_manifest.yaml", timeout => 600);
    wait_for_k8s_job_complete($job_name);
    my $pod = find_pods("job-name=$job_name");
    validate_pod_log($pod, "SUSE Linux Enterprise Server");
    record_info('cmd', "Command `$cmd` successfully executed in the image.");

    # Staging does not have access to repositories, only to DVD
    # curl -sfL https://get.k3s.io is not supported on ppc poo#128456
    if (check_min_runtime_version('4.4.0') && !is_staging && !is_ppc64le) {
        prepare_pod_yaml();
        record_info('Test', 'kube apply');
        assert_script_run('podman kube apply --kubeconfig ~/.kube/config -f pod.yaml', timeout => 180);
        assert_script_run('kubectl wait --timeout=600s --for=condition=Ready pod/testing-pod', timeout => 610);
        validate_script_output('kubectl exec testing-pod -- cat /etc/os-release', sub { m/SUSE Linux Enterprise Server/ }, timeout => 300);
    }

}

sub cleanup {
    my ($self) = @_;
    uninstall_k3s();
}

sub post_fail_hook {
    my ($self) = @_;
    record_info('K3s status', script_output('systemctl status k3s'));
    script_run('journalctl -u k3s --no-pager');
    record_info('K3s nodes', script_output('kubectl get nodes'));
    script_run('kubectl describe nodes');
    record_info('K3s pods', script_output('kubectl get pods --all-namespaces'));
    script_run('kubectl describe pods --all-namespaces');
    script_run('kubectl describe jobs --all-namespaces');
    $self->cleanup();
}

sub post_run_hook {
    my ($self) = @_;
    $self->cleanup();
}


1;
