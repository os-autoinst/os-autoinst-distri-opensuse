# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test kubernetes by deploying nginx
# Maintainer: Martin Kravec <mkravec@suse.com>, Panagiotis Georgiadis <pgeorgiadis@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use utils;
use testapi;
use utils 'script_retry';

sub run {
    # Use downloaded kubeconfig to display basic information
    switch_to 'xterm';
    assert_script_run "kubectl cluster-info";
    assert_script_run "kubectl cluster-info > cluster.before_update";
    assert_script_run "kubectl config view --flatten=true | tee /dev/$serialdev";
    script_retry "kubectl get nodes", delay => 10;
    assert_script_run "! kubectl get cs --no-headers | grep -v Healthy";

    # Check cluster size
    my $nodes_count = get_required_var("STACK_NODES");
    assert_script_run "kubectl get nodes --no-headers | wc -l | grep $nodes_count";

    # Check container runtime [docker|cri-o]
    my $runtime = get_var('CONTAINER_RUNTIME', 'docker');
    assert_script_run "kubectl describe nodes | grep -c Runtime.*$runtime | grep $nodes_count";

    # Deploy nginx minimal application and check pods started succesfully
    my $pods_count = get_required_var("STACK_WORKERS") * 15;
    assert_script_run "kubectl run nginx --image=nginx:stable-alpine --replicas=$pods_count --port=80";

    script_retry 'kubectl get pods | grep -q "0/\|1/2\|No resources"', expect => 1, retry => 10, delay => 10;
    assert_script_run "kubectl get pods | tee /dev/tty | grep -c Running | grep $pods_count";

    # Expose application to access it from controller node
    assert_script_run 'kubectl expose deploy nginx --type=NodePort';
    assert_script_run 'kubectl get all';

    # Check deployed application in firefox
    type_string "NODEPORT=`kubectl get svc | egrep -o '80:3[0-9]{4}' | cut -d: -f2`\n";
    type_string "firefox mixed.openqa.test:\$NODEPORT\n";
    assert_screen 'nginx-alpine';
    send_key 'ctrl-w';
}

1;

