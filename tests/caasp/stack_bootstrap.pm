# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
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
use lockapi 'barrier_wait';
use caasp 'unpause';
use utils;
use version_utils 'is_caasp';


sub accept_nodes {
    # Accept pending nodes
    assert_and_click 'velum-bootstrap-accept-nodes';
    # Nodes are moved from pending
    my $nodes = get_required_var('STACK_NODES');
    assert_screen_with_soft_timeout("velum-$nodes-nodes-accepted", timeout => 150, soft_timeout => 45, bugref => 'bsc#1046663');
    unpause 'NODES_ACCEPTED';
}

sub select_roles {
    # Select all nodes as workers
    assert_and_click 'velum-bootstrap-select-nodes';
    # Wait until warning messages disappears
    wait_still_screen 2;

    # Select master.openqa.test
    send_key_until_needlematch "master-checkbox-xy", 'pgdn', 2, 5;
    click_click xy('master-checkbox-xy');
    # For 6+ node clusters select 2 more random masters
    for (2 .. get_var('STACK_MASTERS')) {
        click_click xy('master-role-button');
    }
}

# Run bootstrap and download kubeconfig
sub bootstrap {
    # Click next button to 'Confirm bootstrap' page
    send_key_until_needlematch 'velum-next', 'pgdn', 2, 5;
    assert_and_click 'velum-next';

    # Accept small-cluster warning
    assert_and_click 'velum-botstrap-warning' if check_var('STACK_NODES', 2);

    # Click bootstrap button
    assert_screen 'velum-confirm-bootstrap';

    # External Kubernetes API & Dashboard FQDN
    for (1 .. 3) { send_key 'tab'; }
    type_string 'master.openqa.test';
    send_key 'tab';
    type_string 'admin.openqa.test';
    assert_and_click "velum-bootstrap";

    # Wait until bootstrap finishes
    assert_screen 'velum-bootstrap-done', 900;
}

sub run {
    assert_screen [qw(velum-bootstrap-page velum-sorry velum-504)], 120;
    # CaaSP 2.0
    if (match_has_tag 'velum-sorry') {
        record_soft_failure('bnc#1074836 - delay caused due to Meltdown');
        # workaround for meltdown
        send_key_until_needlematch 'velum-bootstrap-page', 'f5', 10, 120;
    }
    # CaaSP 3.0
    if (match_has_tag 'velum-504') {
        record_soft_failure('bsc#1080969 - 504 Gateway timed out');
        send_key_until_needlematch 'velum-bootstrap-page', 'f5', 30, 60;
    }
    barrier_wait {name => "WORKERS_INSTALLED", check_dead_job => 1};

    accept_nodes;
    select_roles;
    bootstrap;
    download_kubeconfig;
}

1;

