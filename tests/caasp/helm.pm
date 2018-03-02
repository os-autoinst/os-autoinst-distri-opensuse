# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use Helm, the Kubernetes Package Manager
#   Using Helm to Install Applications
#   Apps taken from: https://hub.kubeapps.com
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use utils;
use testapi;

sub run {
    switch_to 'xterm';

    record_info 'Test #1', 'Configure $HELM_HOME ~/.helm';
    assert_script_run "helm version";
    assert_script_run "helm init";

    record_info 'Test #2', 'Verify that tiller is running on Kubernetes';
    assert_script_run "kubectl get pods --all-namespaces | grep tiller";

    record_info 'Test #3', 'Verify that your have the default repositories configured';
    my $helm_repos =  script_output("helm repo list");
    die('error: Google repo not found') unless ($helm_repos =~ m/stable/);
    die('error: Local repo not found') unless ($helm_repos =~ m/local/);

    record_info 'Test #4', 'Search for a Redis package and use helm to create a release'; 
    assert_script_run "helm search redis | grep redis";
    my $redis_output = script_output("helm install stable/redis");
    die('error: redis deployment failed') unless ($redis_output =~ m/STATUS: DEPLOYED/);

    record_info 'Test #5', 'Verify that you have a redis pod running';
    assert_script_run "helm ls | grep redis | grep DEPLOYED";
    assert_script_run "kubectl get pods | grep redis";
    for (1 .. 10) {
        last if script_run 'kubectl get pods | grep "Running"';
        sleep 10;
    }

    switch_to 'velum';
}

1;

# vim: set sw=4 et:
