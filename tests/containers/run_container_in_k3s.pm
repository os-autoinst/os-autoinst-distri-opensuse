# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Installs local k3s locally and executes a test
# to be sure this is working properly
#
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use publiccloud::utils;
use containers::k8s qw(install_k3s uninstall_k3s apply_manifest wait_for_k8s_job_complete find_pods validate_pod_log);

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
}

sub cleanup {
    my ($self) = @_;
    uninstall_k3s();
}

sub post_fail_hook {
    my ($self) = @_;
    record_info('K3s status', script_output('systemctl status k3s'));
    record_info('K3s nodes', script_output('kubectl get nodes'));
    record_info('K3s pods', script_output('kubectl get pods --all-namespaces'));
    script_run('journalctl -u k3s --no-pager');
    $self->cleanup();
}

sub post_run_hook {
    my ($self) = @_;
    $self->cleanup();
}


1;
