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
use version_utils 'is_caasp';


sub accept_nodes {
    # Accept pending nodes
    assert_and_click 'velum-bootstrap-accept-nodes';
    # Nodes are moved from pending - minus admin job
    my $nodes = get_required_var('STACK_NODES');
    assert_screen_with_soft_timeout("velum-$nodes-nodes-accepted", timeout => 90, soft_timeout => 45, bugref => 'bsc#1046663');
    mutex_create "NODES_ACCEPTED";
}

sub select_nodes {
    # Select all nodes as workers
    assert_and_click 'velum-bootstrap-select-nodes';
    # Wait until warning messages disappears
    wait_still_screen 2;
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
    # Don't click-and-drag
    sleep 1;
    mouse_hide;

    # Give velum time to process
    sleep 2;

    # For 6+ node clusters select 2 more masters
    for (2 .. get_var('STACK_MASTERS')) {
        assert_and_click 'master-role-button';
    }
}

sub setup_root_ca {
    # Close firefox
    send_key 'alt-f4';
    assert_screen 'xterm';

    # Setup ssh
    script_run 'ssh-copy-id -f admin.openqa.test', 0;
    assert_screen 'ssh-password-prompt';
    type_password;
    send_key 'ret';

    # Install certificate
    assert_script_run 'scp admin.openqa.test:/etc/pki/trust/anchors/SUSE_CaaSP_CA.crt .';
    assert_script_run 'certutil -A -n CaaSP -d .mozilla/firefox/*.default -i SUSE_CaaSP_CA.crt -t "C,,"';

    # Start firefox again
    x11_start_program('firefox admin.openqa.test', valid => 0);
    assert_screen 'velum-login';
    velum_login;
    send_key 'f11';
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
    assert_screen [qw(velum-bootstrap-done velum-api-disconnected)], 900;
    setup_root_ca;
    assert_screen 'velum-bootstrap-done', 900;
}

# Download kubeconfig
sub kubectl_config {
    assert_and_click "velum-kubeconfig";

    unless (check_screen('dex-login-page', 5)) {
        record_soft_failure 'bsc#1062542 - dex is not be ready yet';
        sleep 30;
        send_key 'f5';
    }
    assert_screen 'dex-login-page';
    velum_login;

    # Check that kubeconfig downloaded
    assert_screen 'velum-kubeconfig-page';

    # Download takes few seconds
    sleep 5;
    assert_and_click 'velum-kubeconfig-back';
}

sub run {
    assert_screen [qw(velum-bootstrap-page velum-sorry)], 120;
    if (match_has_tag 'velum-sorry') {
        record_soft_failure('bnc#1074836 - delay caused due to Meltdown');
        # workaround for meltdown
        send_key_until_needlematch 'velum-bootstrap-page', 'f5', 10, 120;
    }
    barrier_wait {name => "WORKERS_INSTALLED", check_dead_job => 1};

    accept_nodes;
    select_nodes;
    select_master;
    bootstrap;

    kubectl_config;
}

1;

# vim: set sw=4 et:
