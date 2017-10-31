package caasp_controller;
use base "opensusebasetest";

use strict;
use testapi;
use lockapi;
use caasp 'get_admin_job';

use Exporter 'import';
our @EXPORT = qw(confirm_insecure_https velum_login);

# Register and login to velum and dex
sub velum_login {
    my $register = shift;

    type_string 'email@email.com';
    send_key 'tab';
    type_string 'password';
    if ($register) {
        send_key 'tab';
        type_string 'password';
    }
    sleep 1;
    save_screenshot;
    send_key 'ret';
}

# Users have to confirm certificate 3 times during deployment
sub confirm_insecure_https {
    wait_still_screen 3;
    assert_and_click 'velum-https-advanced';
    assert_and_click 'velum-https-add_exception';
    assert_and_click 'velum-https-confirm';
}

# Base class for CaaSP tests
sub test_flags {
    return {fatal => 1};
}

# Controller job is parent. If it fails we need to export deployment logs from child jobs
# Without this post_fail_hook they would stop with parallel_failed result
sub post_fail_hook {
    # Destroy barriers and create mutexes to avoid deadlock
    barrier_destroy "WORKERS_INSTALLED";
    mutex_create "NODES_ACCEPTED";
    mutex_create 'VELUM_CONFIGURED';
    mutex_create "CNTRL_FINISHED";

    # Wait for log export from admin node
    mutex_lock "ADMIN_LOGS_EXPORTED", get_admin_job;
}

1;
# vim: set sw=4 et:
