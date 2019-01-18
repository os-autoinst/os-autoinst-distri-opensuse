package caasp_controller;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use caasp qw(unpause script_assert0);
use lockapi 'barrier_destroy';
use mmapi 'wait_for_children';
use version_utils 'is_caasp';

use Exporter 'import';
our @EXPORT = qw($admin_fqdn $master_fqdn salt
  velum_login switch_to download_kubeconfig click_click xy);

our $admin_fqdn = 'admin.openqa.test';
# Extra space to check for bsc#1087447
our $master_fqdn = ' master-api.openqa.test ';

# 10% of clicks are lost because ajax refreshes Velum during click
# bsc#1048975 - User interaction is lost after page refresh
sub click_click {
    my ($x, $y) = @_;
    mouse_set $x, $y;
    for (1 .. 2) {
        mouse_click;
        # Don't click-and-drag
        sleep 1;
    }
    mouse_hide;
}

# Get xy coordinates for:
# - 1 needle  1 area    : center of a needle
# - 1 needle  2 areas   : intersection of 2 areas   (n1a1 => x, n1aN => y)
# - 2 needles 1|2 areas : intersection of 2 needles (n1a1 => x, n2aN => y)
sub xy {
    my ($tag0, $tag1) = @_;
    my $as;

    # Get x position from first needle & first area
    $as = assert_screen($tag0)->{area};
    my $x = $as->[0]{x} + int($as->[0]{w} / 2);
    # Get y position from last needle & last area
    $as = assert_screen($tag1)->{area} if $tag1;
    my $y = $as->[-1]{y} + int($as->[-1]{h} / 2);

    return ($x, $y);
}

# Easier switching between applications
# xterm | velum
sub switch_to {
    my $app = shift;
    send_key_until_needlematch "switch-to-$app", 'alt-tab', 1;
}

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

# Executes salt command on admin node.
# Escaping: ' is OK; " and spacial chars need to be escaped
# Params: target [admin|kube-master|kube-minion]; timeout
# Example: salt "cmd.run SUSEConnect -d", target => 'kube-(master|minion)', timeout => 20;
sub salt {
    my ($cmd, %args) = @_;

    my $update_args = qq#-e "$cmd"#;
    $update_args .= qq# -t "roles:$args{target}"# if $args{target};

    record_info './update.sh exec', "ssh $admin_fqdn './update.sh $update_args'";
    script_assert0("ssh $admin_fqdn './update.sh $update_args' | tee /dev/$serialdev", $args{timeout});
}

# Base class for CaaSP tests
sub test_flags {
    return {fatal => 1};
}

# Controller job is parent. If it fails we need to export deployment logs from child jobs
# Without this post_fail_hook they would stop with parallel_failed result
sub post_fail_hook {
    # Variable to enable failed cluster debug
    sleep if check_var('DEBUG_SLEEP', 'controller');

    # Destroy barriers and create mutexes to avoid deadlock
    barrier_destroy 'NODES_ONLINE';
    barrier_destroy 'DELAYED_NODES_ONLINE';
    unpause 'ALL';

    # Wait for log export from all nodes
    wait_for_children;
}

# Original kubeconfig will be replaced
sub download_kubeconfig {
    assert_and_click 'velum-kubeconfig';

    unless (check_screen('dex-login-page', 5)) {
        record_soft_failure 'bsc#1062542 - dex is not be ready yet';
        sleep 30;
        send_key 'f5';
    }
    assert_screen 'dex-login-page';
    velum_login;

    assert_screen [qw(velum-kubeconfig-page velum-nonce-error)];
    if (match_has_tag 'velum-nonce-error') {
        record_soft_failure 'bsc#1081007 - Invalid ID Token: Nonce does not match';
        assert_and_click "velum-kubeconfig";
        assert_screen 'dex-login-page';
        velum_login;
        assert_screen 'velum-kubeconfig-page';
    }

    assert_and_click 'firefox-downloading-save_enabled';
    assert_and_click 'velum-kubeconfig-back';
    assert_screen 'velum-bootstrap-done';

    # Stay on xterm after download
    switch_to 'xterm';
    assert_script_run 'mv ~/Downloads/kubeconfig ~/.kube/config';
    upload_logs('.kube/config', log_name => 'kubectl-' . time);
}

1;
