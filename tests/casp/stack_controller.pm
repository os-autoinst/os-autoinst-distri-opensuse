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
#   Configured ntpd server (using local clock)
#   Firefox:
#     - disabled readerview, password remember, bookmarks bar
#     - startup page, search tips, auto-save to disk
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
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
    for (1 .. 5) { send_key 'tab' }
    type_string "node1.openqa.test";
    send_key 'tab';
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
    save_screenshot;
    send_key 'ret';

    assert_screen 'velum-tips-page';
    assert_and_click "velum-next";
}

# Run bootstrap and download kubeconfig
sub velum_bootstrap {
    assert_screen 'velum-bootstrap-page';
    barrier_wait "WORKERS_INSTALLED";

    # Select master and bootstrap
    assert_and_click "select-master";
    assert_and_click "velum-bootstrap";

    assert_screen "velum-botstrap-done", 300;
    assert_and_click "velum-kubeconfig";
}

# Setup while waiting for admin dashboard installation
sub initialize {
    x11_start_program "xterm";
    assert_screen "xterm";

    # Fix permissions
    assert_script_sudo "chown $testapi::username /dev/$testapi::serialdev";
    # Disable screensaver
    script_run "gsettings set org.gnome.desktop.session idle-delay 0";
    send_key "ctrl-d";

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

    # Velum tests
    velum_signup;
    velum_certificates;
    velum_bootstrap;

    # Use downloaded kubeconfig to display basic information
    select_console "user-console";
    type_string "export KUBECONFIG=Downloads/kubeconfig\n";
    assert_script_run "kubectl cluster-info";
    assert_script_run "kubectl get nodes";

    barrier_wait "CNTRL_FINISHED";
    wait_for_children;
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

# Controller job is parent. If it fails we need to export deployment logs from child jobs
# Without this post_fail_hook they would stop with parallel_failed result
sub post_fail_hook {
    barrier_wait "CNTRL_FINISHED";
    wait_for_children;
}

1;

# vim: set sw=4 et:
