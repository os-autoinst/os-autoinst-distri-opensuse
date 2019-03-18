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
use warnings;
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

    # Select Kubernetes API FQDN
    send_key_until_needlematch "master-api-setrole-xy", 'pgdn', 2, 5;
    click_click xy('master-api-setrole-xy');

    # For bigger clusters select 2 more masters
    if (check_var('STACK_MASTERS', 3)) {
        send_key 'home';
        send_key_until_needlematch "master-rm-setrole-xy", 'pgdn', 2, 5;
        click_click xy('master-rm-setrole-xy');

        send_key 'home';
        send_key_until_needlematch "master-ay-setrole-xy", 'pgdn', 2, 5;
        click_click xy('master-ay-setrole-xy');
    }
}

# Run bootstrap and download kubeconfig
sub bootstrap {
    # CaaSP 2.0 will keep bsc#1087447
    $master_fqdn =~ s/^ | $//g if is_caasp('=2.0');

    # Click next button to 'Confirm bootstrap' page
    send_key_until_needlematch 'velum-next', 'pgdn', 2, 5;
    assert_and_click 'velum-next';

    # Accept small-cluster warning
    assert_and_click 'velum-botstrap-warning' if check_var('STACK_NODES', 2);

    # Click bootstrap button
    assert_screen 'velum-confirm-bootstrap';

    # External Kubernetes API & Dashboard FQDN
    for (1 .. 3) { send_key 'tab'; }
    type_string $master_fqdn;
    send_key 'tab';
    type_string $admin_fqdn;
    assert_and_click "velum-bootstrap";

    # Bootstrap & retry in case of failure
    assert_screen ['velum-status-error', 'velum-bootstrap-done'], 900;
    if (match_has_tag 'velum-status-error') {
        assert_and_click 'velum-retry';
        assert_screen 'velum-bootstrap-done', 900;
    }
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
    barrier_wait {name => "NODES_ONLINE", check_dead_job => 1};
    sleep 30;    # Wait for salt-minion requests

    accept_nodes;
    select_roles;
    bootstrap;
    download_kubeconfig;
}

1;

