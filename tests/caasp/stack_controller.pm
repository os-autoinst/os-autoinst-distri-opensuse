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

my $admin_email    = 'email@email.com';
my $admin_password = 'password';

# Create admin account
sub velum_signup {
    assert_and_click 'create-an-account';
    assert_screen 'velum-signup';
    type_string $admin_email;
    send_key 'tab';
    type_string $admin_password;
    send_key 'tab';
    type_string $admin_password;
    save_screenshot;
    send_key 'ret';
}

# Fill certificate information
sub velum_certificates {
    assert_screen 'velum-certificates-page';

    # Fill generic settings
    for (1 .. 4) { send_key 'tab' }
    type_string "master.openqa.test";
    assert_and_click "velum-next";

    assert_screen 'velum-tips-page';
    assert_and_click "velum-next";
}

sub confirm_insecure_https {
    assert_and_click 'velum-https-advanced';
    assert_and_click 'velum-https-add_exception';
    assert_and_click 'velum-https-confirm';
}

# Run bootstrap and download kubeconfig
sub velum_bootstrap {
    assert_screen 'velum-bootstrap-page', 90;
    barrier_wait "WORKERS_INSTALLED";

    # Accept pending nodes
    assert_and_click 'velum-bootstrap-accept-nodes';
    # Nodes are moved from pending - minus admin & controller
    my $nodes = get_var('STACK_SIZE') - 2;
    assert_screen_with_soft_timeout("velum-$nodes-nodes-accepted", timeout => 90, soft_timeout => 45, bugref => 'bsc#1046663');
    mutex_create "NODES_ACCEPTED";

    # Select all nodes as workers
    assert_and_click 'velum-bootstrap-select-nodes';

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

    # Wait until warning messages disappears
    wait_still_screen;

    if (check_var('DISTRI', 'caasp') && !check_var('VERSION', '1.0')) {
        # Click next button to 'Confirm bootstrap' page [version >= 2.0]
        send_key_until_needlematch 'velum-next', 'pgdn', 2, 5;
        assert_and_click 'velum-next';

        # Accept small-cluster warning
        assert_and_click 'velum-botstrap-warning' if check_var('STACK_SIZE', 4);

        # Click bootstrap button [version >= 2.0]
        assert_screen 'velum-confirm-bootstrap';

        # External Dashboard FQDN
        for (1 .. 3) { send_key 'tab'; }
        type_string 'admin.openqa.test';
        assert_and_click "velum-bootstrap";
    }
    else {
        # Click bootstrap button [CaaSP 1.0]
        send_key_until_needlematch "velum-bootstrap", "pgdn", 2, 5;
        assert_and_click "velum-bootstrap";
    }

    # Workaround for bsc#1064641
    assert_screen [qw(velum-bootstrap-done velum-api-disconnected)], 900;
    if (match_has_tag('velum-api-disconnected')) {
        record_soft_failure 'bsc#1064641 - Velum polling breaks after bootstrap';
        send_key 'f5';
        confirm_insecure_https;
        assert_screen 'velum-bootstrap-done', 900;
    }

    assert_and_click "velum-kubeconfig";
    if (check_var('DISTRI', 'caasp') && !check_var('VERSION', '1.0')) {
        confirm_insecure_https;
        type_string $admin_email;
        send_key 'tab';
        type_string $admin_password;
        send_key 'tab';
        save_screenshot;
        send_key 'ret';
        sleep 1;
        save_screenshot;
    }
}

# Setup while waiting for admin dashboard installation
sub initialize {
    x11_start_program('xterm');

    # Fix permissions
    assert_script_sudo "chown $testapi::username /dev/$testapi::serialdev";
    # Disable screensaver
    script_run "gsettings set org.gnome.desktop.session idle-delay 0";

    # Leave xterm open for kubernetes tests
    save_screenshot;
    send_key "ctrl-l";
    send_key 'super-up';
    x11_start_program('firefox', valid => 0);
}

sub run {
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

    # Check cluster size
    # CaaSP 2.0 = %number_of_jobs - minus two (controller & admin) jobs
    my $minion_count = get_required_var("STACK_SIZE") - 2;
    if (check_var('DISTRI', 'caasp') && check_var('VERSION', '1.0')) {
        # CaaSP 1.0 = %number_of_jobs - minus three (controller + admin + master) jobs
        $minion_count = get_required_var("STACK_SIZE") - 3;
    }
    my $temp = get_required_var("STACK_SIZE");
    assert_script_run "echo $temp";
    assert_script_run "echo $minion_count";
    assert_script_run "kubectl get nodes --no-headers | wc -l | grep $minion_count";

    # Deploy nginx minimal application and check pods started succesfully
    my $pods_count = $minion_count * 15;
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

sub test_flags {
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
