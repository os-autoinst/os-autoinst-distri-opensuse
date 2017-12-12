# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test kubernetes by deploying nginx
# Maintainer: Martin Kravec <mkravec@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use utils;
use testapi;

sub run {
    # Use downloaded kubeconfig to display basic information
    switch_to 'xterm';
    type_string "export KUBECONFIG=~/Downloads/kubeconfig\n";

    assert_script_run "kubectl cluster-info";
    assert_script_run "kubectl get nodes";
    assert_script_run "! kubectl get cs --no-headers | grep -v Healthy";

    # Check cluster size
    my $nodes_count = get_required_var("STACK_NODES");
    assert_script_run "kubectl get nodes --no-headers | wc -l | grep $nodes_count";

    # Deploy nginx minimal application and check pods started succesfully
    my $pods_count = get_required_var("STACK_MINIONS") * 15;
    assert_script_run "kubectl run nginx --image=nginx:alpine --replicas=$pods_count --port=80";
    for (1 .. 10) {
        last if script_run 'kubectl get pods | grep -q "0/\|1/2\|No resources"';
        sleep 10;
    }
    assert_script_run "kubectl get pods | tee /dev/tty | grep -c Running | grep $pods_count";

    # Expose application to access it from controller node
    assert_script_run 'kubectl expose deploy nginx --type=NodePort';
    assert_script_run 'kubectl get all';

    # Check deployed application in firefox
    type_string "NODEPORT=`kubectl get svc | egrep -o '80:3[0-9]{4}' | cut -d: -f2`\n";
    type_string "firefox node1.openqa.test:\$NODEPORT\n";
    assert_screen 'nginx-alpine';
    send_key 'ctrl-w';
}

1;

# vim: set sw=4 et:
