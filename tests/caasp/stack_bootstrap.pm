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
use lockapi;
use utils;
use version_utils 'is_caasp';


sub accept_nodes {
    # Accept pending nodes
    assert_and_click 'velum-bootstrap-accept-nodes';
    # Nodes are moved from pending
    my $nodes = get_required_var('STACK_NODES');
    assert_screen_with_soft_timeout("velum-$nodes-nodes-accepted", timeout => 150, soft_timeout => 45, bugref => 'bsc#1046663');
    mutex_create "NODES_ACCEPTED";
}

sub select_nodes {
    # Select all nodes as workers
    assert_and_click 'velum-bootstrap-select-nodes';
    # Wait until warning messages disappears
    wait_still_screen 2;
}

# 10% of clicks are lost because of ajax refreshing Velum during click
sub click_click {
    my ($x, $y) = @_;
    mouse_set $x, $y;
    for (1 .. 3) {
        mouse_click;
        # Don't click-and-drag
        sleep 1;
    }
    mouse_hide;
    record_info 'bsc#1048975', 'User interaction is lost after page refresh';
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
    click_click $x, $y;

    # For 6+ node clusters select 2 more random masters
    for (2 .. get_var('STACK_MASTERS')) {
        $needle = assert_screen('master-role-button')->{area};
        $row    = $needle->[0];
        $y      = $row->{y} + int($row->{h} / 2);
        click_click $x, $y;
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
    select_nodes;
    select_master;
    bootstrap;

    download_kubeconfig;
}

1;

