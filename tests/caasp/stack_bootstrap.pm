# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bootstrap cluster
# Maintainer: Martin Kravec <mkravec@suse.com>
use parent 'caasp_controller';
use caasp_controller;

use strict;
use testapi;
use lockapi;
use utils;
use mmapi 'get_children_by_state';

sub wait_for_workers {
    my $children = @{get_children_by_state 'running'};
    die "Some worker job died" unless check_var('STACK_SIZE', $children);
    barrier_wait "WORKERS_INSTALLED";
}

sub accept_nodes {
    # Accept pending nodes
    assert_and_click 'velum-bootstrap-accept-nodes';
    # Nodes are moved from pending - minus admin job
    my $nodes = get_var('STACK_SIZE') - 1;
    assert_screen_with_soft_timeout("velum-$nodes-nodes-accepted", timeout => 90, soft_timeout => 45, bugref => 'bsc#1046663');
    mutex_create "NODES_ACCEPTED";
}

sub select_nodes {
    # Select all nodes as workers
    assert_and_click 'velum-bootstrap-select-nodes';
    # Wait until warning messages disappears
    wait_still_screen 3;
}

# Select master.openqa.test and additional master nodes
sub select_master {
    # Calculate position of master node
    send_key_until_needlematch "master-checkbox-xy", "pgdn", 2, 5;
    my $needle = assert_screen('master-checkbox-xy')->{area};
    my $row    = $needle->[0];                                  # get y-position of master node
    my $col    = $needle->[1];                                  # get x-position of checkbox
    my $x      = $col->{x} + int($col->{w} / 2);
    my $y      = $row->{y} + int($row->{h} / 2);

    # Select master node
    mouse_set $x, $y;
    mouse_click;
    mouse_hide;

    # Give velum time to process
    sleep 2;

    # For 6+ node clusters select 2 more masters
    if (is_caasp('2.0+') && get_var('STACK_SIZE') > 6) {
        for (1 .. 2) {
            assert_and_click 'master-role-button';
            sleep 2;    # bsc#1066371 workaround
        }
    }
}

# Run bootstrap and download kubeconfig
sub bootstrap {
    # Start bootstrap
    if (is_caasp '2.0+') {
        # Click next button to 'Confirm bootstrap' page
        send_key_until_needlematch 'velum-next', 'pgdn', 2, 5;
        assert_and_click 'velum-next';

        # Accept small-cluster warning
        assert_and_click 'velum-botstrap-warning' if check_var('STACK_SIZE', 3);

        # Click bootstrap button
        assert_screen 'velum-confirm-bootstrap';

        # External Kubernetes API & Dashboard FQDN
        for (1 .. 3) { send_key 'tab'; }
        type_string 'master.openqa.test';
        send_key 'tab';
        type_string 'admin.openqa.test';
        assert_and_click "velum-bootstrap";
    }
    else {
        # Click bootstrap button [CaaSP 1.0]
        send_key_until_needlematch "velum-bootstrap", "pgdn", 2, 5;
        assert_and_click "velum-bootstrap";
    }

    # Wait until bootstrap finishes
    assert_screen [qw(velum-bootstrap-done velum-api-disconnected)], 900;
    if (match_has_tag('velum-api-disconnected')) {
        # Velum API needs a moment to restart
        send_key_until_needlematch 'velum-https-advanced', 'f5', 2, 5;
        confirm_insecure_https;
        assert_screen 'velum-bootstrap-done', 900;
    }
}

# Download kubeconfig
sub kubectl_config {
    assert_and_click "velum-kubeconfig";
    if (is_caasp '2.0+') {
        unless (check_screen('velum-https-advanced', 5)) {
            record_soft_failure 'bsc#1062542 - dex is not be ready yet';
            sleep 30;
            send_key 'f5';
        }
        confirm_insecure_https;
        velum_login;

        # Check that kubeconfig downloaded
        assert_screen 'velum-kubeconfig-page';
    }
    # Download takes few seconds
    sleep 5;
    save_screenshot;
}

sub run {
    assert_screen 'velum-bootstrap-page', 90;
    wait_for_workers;

    accept_nodes;
    select_nodes;
    select_master;
    bootstrap;

    kubectl_config;
}

1;

# vim: set sw=4 et:
