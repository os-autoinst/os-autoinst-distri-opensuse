# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate deployed Kubernetes
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use elemental3;

sub run {
    my $k8s = get_required_var('K8S');
    my $k8s_dir = "/etc/rancher/$k8s";
    my $timeout = 2400;    # Will be adapted when we will have more successful tests

    # Wait for K8s directory to appears
    wait_on_cmd(cmd => "test -d $k8s_dir", timeout => $timeout);

    # Record K8s configuration files
    record_info("$k8s_dir config files", "ls -l $k8s_dir; echo; cat $k8s_dir/*");

    # Wait for kubectl command to be available
    wait_kubectl_cmd(timeout => $timeout);

    # Check K8s status
    wait_k8s_state(regex => 'status.*restarts|(1/1|2/2|3/3|4.4).*running|0/1.*completed', timeout => $timeout);

    # Record K8s status (we want all, stderr as well)
    record_info('K8s status', script_output('kubectl get pod -A 2>&1'));

    # Wait until node(s) is/are in Ready state
    wait_nodes_ready(timeout => $timeout);

    # Record K8s version/nodes
    record_info('K8s version/nodes', script_output('kubectl version; kubectl get nodes'));

    # Record K8s services
    record_info('K8s services', script_output('kubectl get services -A'));

    # Check toolkit version
    record_info('Elemental version', script_output('elemental3ctl version'));

    # Check that test namespace has been created
    kubectl_cmd(cmd => 'get namespace openqa-ns', timeout => $timeout);
    record_info('Test Namespace creation', 'Namespace created!');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
