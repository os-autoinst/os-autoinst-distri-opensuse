# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add new node to cluster after bootstrap is finished
# Maintainer: Martin Kravec <mkravec@suse.com>
use parent 'caasp_controller';
use caasp_controller;

use strict;
use testapi;
use lockapi;

sub accept_nodes {
    # Accept pending nodes
    send_key_until_needlematch 'velum-bootstrap-accept-nodes', 'pgdn', 2, 3;
    assert_and_click 'velum-bootstrap-accept-nodes';
    save_screenshot;
    send_key 'home';

    # Nodes are moved from pending to new
    assert_and_click "velum-1-nodes-accepted", 'left', 90;
    mutex_create "DELAYED_NODES_ACCEPTED";
}

sub bootstrap {
    assert_and_click 'unassigned-select-all';
    assert_and_click 'unassigned-add-nodes';
    assert_screen 'velum-bootstrap-done';
    send_key 'end';
    assert_screen 'velum-adding-nodes-done', 900;
    send_key 'home';
}

sub run {
    mutex_lock 'DELAYED_WORKER_INSTALLED', get_required_var('STACK_DELAYED');
    accept_nodes;
    bootstrap;

    # Kubernetes checks
    switch_to 'xterm';
    assert_script_run "kubectl cluster-info";
    my $nodes_count = get_required_var("STACK_NODES") + 1;
    assert_script_run "kubectl get nodes --no-headers | wc -l | grep $nodes_count";
    switch_to 'velum';
}

1;

# vim: set sw=4 et:
