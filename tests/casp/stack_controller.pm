# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Connect to velum and bootstrap cluster
# Manual modifications to controller node:
#   Installed packages for DHCP, DNS and enable them in firewall
#   Installer kubernetes-client from virtualization repo
#   Firefox:
#     - disabled readerview, password remember, bookmarks bar
#     - startup page, search tips, auto-save to disk
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils 'assert_screen_with_soft_timeout';
use lockapi;
use mmapi;

# Create admin account
sub velum_signup {
    assert_and_click 'create-an-account';
    assert_screen 'velum-signup';
    type_string 'email@email.com';
    send_key 'tab';
    type_string 'password';
    send_key 'tab';
    type_string 'password';
    save_screenshot;
    send_key 'ret';
}

# Fill certificate information
sub velum_certificates {
    assert_screen 'velum-certificates-page';

    # Fill generic settings
    for (1 .. 4) { send_key 'tab' }
    type_string "master.openqa.test";

    # Staging workaround
    unless (check_screen 'velum-proxy-optional') {
        # Skip proxy settings
        for (1 .. 4) { send_key 'tab' }

        # Fill certificate settings
        type_string "SUSE";
        send_key 'tab';
        type_string "QA";
        send_key 'tab';
        type_string "email\@email.com";
        send_key 'tab';
        type_string "cz";
        send_key 'tab';
        type_string "CZ";
        send_key 'tab';
        type_string "Prague";
    }
    save_screenshot;
    send_key 'ret';

    assert_screen 'velum-tips-page';
    assert_and_click "velum-next";
}

# Run bootstrap and download kubeconfig
sub velum_bootstrap {
    assert_screen 'velum-bootstrap-page', 90;
    barrier_wait "WORKERS_INSTALLED";

    # Accept pending nodes
    assert_and_click 'velum-bootstrap-accept-nodes';
    # Nodes are moved from pending - minus admin & controller
    my $nodes = get_var('STACK_SIZE') - 2;
    assert_screen_with_soft_timeout("velum-$nodes-nodes-accepted", timeout => 90, soft_timeout => 15, bugref => 'bsc#1046663');

    # Select all nodes for bootstrap
    assert_and_click 'velum-bootstrap-select-nodes';

    # Calculate position of master node radio button
    send_key_until_needlematch "master-checkbox-xy", "pgdn", 2, 5;
    my $needle = assert_screen('master-checkbox-xy')->{area};
    my $row    = $needle->[0];                                  # get y-position of master node
    my $col    = $needle->[1];                                  # get x-position of checkbox
    my $x      = $col->{x} + int($col->{w} / 2);
    my $y      = $row->{y} + int($row->{h} / 2);

    # Select master
    mouse_set $x, $y;
    sleep 0.5;
    mouse_click;

    # Click bootstrap button
    send_key_until_needlematch "velum-bootstrap", "pgdn", 2, 5;
    assert_and_click "velum-bootstrap";
    mouse_hide;

    # Accept small-cluster warning
    assert_and_click 'velum-botstrap-warning' if check_var('STACK_SIZE', 4);

    assert_screen "velum-botstrap-done", 300;
    assert_and_click "velum-kubeconfig";
}

sub confirm_insecure_https {
    # Workaround for non-staging
    return if check_screen('create-an-account', 10);
    assert_and_click 'velum-https-advanced';
    assert_and_click 'velum-https-add_exception';
    assert_and_click 'velum-https-confirm';
}

# Setup while waiting for admin dashboard installation
sub initialize {
    x11_start_program "xterm";
    assert_screen "xterm";

    # Fix permissions
    assert_script_sudo "chown $testapi::username /dev/$testapi::serialdev";
    # Disable screensaver
    script_run "gsettings set org.gnome.desktop.session idle-delay 0";

    # Leave xterm open for kubernetes tests
    save_screenshot;
    send_key "ctrl-l";
    send_key 'super-up';
    x11_start_program("firefox");
}

sub run() {
    select_console 'x11';

    # Setup and wait until dashboard becomes ready
    initialize;
    barrier_wait "VELUM_STARTED";

    # Display velum dashboard
    type_string get_var('DASHBOARD_URL');
    send_key 'ret';
    send_key "f11";
    confirm_insecure_https;

    # Bootstrap cluster and download kubeconfig
    velum_signup;
    velum_certificates;
    velum_bootstrap;

    # Use downloaded kubeconfig to display basic information
    send_key "alt-tab";
    assert_screen 'xterm';
    type_string "export KUBECONFIG=~/Downloads/kubeconfig\n";
    assert_script_run "kubectl cluster-info";
    assert_script_run "kubectl get nodes";

    # Check cluster size - minus controller & admin & master jobs
    my $minion_count = get_required_var("STACK_SIZE") - 3;
    assert_script_run "kubectl get nodes --no-headers | wc -l | grep $minion_count";

    # Deploy nginx minimal application and check pods started succesfully
    my $pods_count = $minion_count * 3;
    assert_script_run "kubectl run nginx --image=nginx:alpine --replicas=$pods_count --port=80";
    type_string "kubectl get pods --watch\n";
    wait_still_screen 15, 60;
    send_key "ctrl-c";
    assert_script_run "kubectl get pods | grep -c Running | grep $pods_count";

    # Expose application to access it from controller node
    assert_script_run 'kubectl expose deploy nginx --type=NodePort';
    assert_script_run 'kubectl get all';

    # Check deployed application in firefox
    type_string "NODEPORT=`kubectl get svc | egrep -o '80:3[0-9]{4}' | cut -d: -f2`\n";
    type_string "firefox node1.openqa.test:\$NODEPORT\n";
    assert_screen 'nginx-alpine';

    barrier_wait "CNTRL_FINISHED";
    wait_for_children;
}

sub test_flags() {
    return {fatal => 1};
}

# Controller job is parent. If it fails we need to export deployment logs from child jobs
# Without this post_fail_hook they would stop with parallel_failed result
sub post_fail_hook {
    barrier_wait "CNTRL_FINISHED";
    wait_for_children;
}

1;

# vim: set sw=4 et:
