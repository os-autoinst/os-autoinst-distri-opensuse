# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Update cluster from OBS repository
#   SSH keys are already generated
#   SSH config was modified to not check identity
#   Script is not run on admin to avoid mutex hell
# Maintainer: Martin Kravec <mkravec@suse.com>

use parent 'caasp_controller';
use caasp_controller;

use strict;
use testapi;
use lockapi 'mutex_create';
use caasp 'update_scheduled';

# Set up ssh to admin node and run update script on all nodes
sub setup_update_repository {
    my $repo = update_scheduled;

    # Switch to xterm
    send_key 'alt-tab';    # select_console 'user-console'
    script_run 'ssh-copy-id -f admin.openqa.test', 0;
    assert_screen 'ssh-password-prompt';
    type_password;
    send_key 'ret';
    assert_script_run "ssh admin.openqa.test './update.sh -s $repo' | tee /dev/$serialdev | grep EXIT_OK", 120;

    # Switch to velum
    send_key 'alt-tab';    # select_console 'x11';
}

# Check that update changed system as expected
sub check_update_changes {
    # Switch to xterm
    send_key 'alt-tab';    # select_console 'user-console'

    # Kubernetes checks
    assert_script_run "kubectl cluster-info";
    assert_script_run "! kubectl get cs --no-headers | grep -v Healthy";
    my $nodes_count = get_required_var("STACK_NODES");
    assert_script_run "kubectl get nodes --no-headers | wc -l | grep $nodes_count";

    # Containers check
    # QAM: incidents repo with real maintenance updates
    if (check_var('FLAVOR', 'CaaSP-DVD-Incidents')) {
        # TODO
    }
    else {
        # QA: fake repo with pre-defined values (hardcoded)
        assert_script_run "ssh admin.openqa.test './update.sh -c' | tee /dev/$serialdev | grep EXIT_OK", 60;
    }

    # Switch to velum
    send_key 'alt-tab';    # select_console 'x11';
}

sub run {
    setup_update_repository;

    my $nodes = get_required_var('STACK_NODES');
    assert_screen "velum-$nodes-nodes-outdated";
    die "Can't update nodes before admin" if check_screen "velum-update-all", 0;

    # Update admin node (~160s for admin reboot)
    assert_and_click 'velum-update-admin';
    assert_and_click 'velum-update-reboot';

    # Update all nodes - this part takes long time (~2 minutes per node)
    assert_screen "velum-$nodes-nodes-outdated", 300;
    die "Admin should be updated already" if check_screen 'velum-update-admin', 0;
    assert_and_click "velum-update-all";

    assert_screen 'velum-bootstrap-done', $nodes * 150;
    die "Nodes should be updated already" if check_screen "velum-0-nodes-outdated", 0;

    check_update_changes;
    mutex_create 'UPDATE_FINISHED';
}

1;

# vim: set sw=4 et:
