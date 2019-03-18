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
use caasp qw(pause_until get_delayed);
use lockapi 'barrier_wait';

use strict;
use warnings;
use testapi;


sub accept_delayed_nodes {
    # Accept pending nodes
    send_key 'end';
    assert_and_click 'velum-bootstrap-accept-nodes';
    wait_still_screen;

    # Nodes are moved from pending to new
    send_key 'home';
    my $n = get_var 'STACK_DELAYED';
    assert_screen "velum-$n-nodes-accepted", 90;
}

# Select node and role based on needle match
sub add_node {
    my $node = shift;
    record_info 'Add node', $node;

    click_click xy('velum-new-nodes');
    click_click xy("$node-setrole-xy");
    assert_and_click 'unassigned-add-nodes';
    assert_screen 'velum-bootstrap-done';
    send_key 'end';

    # Wait until node is added or error
    assert_screen ['velum-adding-nodes-done', 'velum-status-error'], 1500;
    die 'Adding node failed' if match_has_tag('velum-status-error');
}

# Remove node based on needle match
sub remove_node {
    my $node = shift;
    my %args = @_;

    record_info 'Remove node', $node;
    send_key_until_needlematch "$node-remove-xy", 'pgdn', 2, 5;
    click_click xy("$node-remove-xy");
    assert_and_click 'confirm-removal';
    if ($args{unsupported}) {
        wait_still_screen 3;
        assert_and_click 'confirm-unsupported';
    }

    # Wait until node is removed or error
    my $timer = time + 1500;
    assert_screen "$node-pending";
    while (check_screen "$node-pending", 5) {
        sleep 25;
        die 'Node removal timeout' if $timer - time < 0;
        die 'Node removal failed' if check_screen('velum-status-error', 0);
    }
    send_key 'home';
}

# Has also function of wait_still_screen
sub check_kubernetes {
    my $nodes_count = shift;
    switch_to 'xterm';
    assert_script_run "kubectl get nodes --no-headers | tee /dev/tty | wc -l | grep $nodes_count";
    switch_to 'velum';
}

sub run {
    switch_to 'velum';
    barrier_wait {name => 'DELAYED_NODES_ONLINE', check_dead_job => 1};

    accept_delayed_nodes;
    my $n = get_required_var('STACK_NODES');

    if (get_delayed 'worker') {
        add_node 'worker-addrm';
        check_kubernetes($n + 1);

        remove_node 'worker-addrm';
        check_kubernetes($n);
    }

    if (check_var 'STACK_MASTERS', 3) {
        remove_node 'master-rm', unsupported => 1;
        check_kubernetes($n - 1);

        if (get_delayed 'master') {
            add_node 'master-add';
            check_kubernetes($n);
        }
    }
}

1;
