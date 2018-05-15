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
use caasp qw(pause_until unpause);

use strict;
use testapi;

sub add_nodes {
    # Accept pending nodes
    send_key_until_needlematch 'velum-bootstrap-accept-nodes', 'pgdn', 2, 3;
    assert_and_click 'velum-bootstrap-accept-nodes';
    save_screenshot;
    send_key 'home';

    # Nodes are moved from pending to new
    assert_and_click "velum-1-nodes-accepted", 'left', 90;
    unpause 'DELAYED_NODES_ACCEPTED';

    # Bootstrap new node
    wait_still_screen 3;
    assert_and_click 'unassigned-select-all';
    assert_and_click 'unassigned-add-nodes';
    assert_screen 'velum-bootstrap-done';
    send_key 'end';
    assert_screen 'velum-adding-nodes-done', 900;
}

sub remove_nodes {
    mouse_set xy('delayed-remove-xy');
    mouse_click;
    assert_and_click 'confirm-removal';
    sleep 7;
    assert_screen 'velum-adding-nodes-done', 900;
    send_key 'home';
}

sub check_kubernetes {
    my $nodes_count = shift;
    switch_to 'xterm';
    assert_script_run "kubectl cluster-info";
    assert_script_run "kubectl get nodes --no-headers | tee /dev/tty | wc -l | grep $nodes_count";
    switch_to 'velum';
}

sub run {
    pause_until 'DELAYED_WORKER_INSTALLED';

    record_info 'Add node';
    add_nodes;
    check_kubernetes(get_required_var('STACK_NODES') + 1);

    record_info 'Remove node';
    remove_nodes;
    check_kubernetes(get_required_var('STACK_NODES'));
}

1;

