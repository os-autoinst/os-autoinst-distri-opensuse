# SUSE"s openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Deploy X11, pulseaudio, firefox kiosk
#          with Kubernetes Using Helm
# Maintainer: Grace Wang <grace.wang@suse.com>

use base 'consoletest';
use testapi;
use lockapi;
use mmapi;
use utils;
use mm_network 'setup_static_mm_network';
use containers::k8s;
use transactional;

# MM network check: try to ping the gateway, the client and the internet
sub ensure_client_reachable {
    assert_script_run('ping -c 1 10.0.2.2');
    assert_script_run('ping -c 1 10.0.2.102');
    assert_script_run('curl conncheck.opensuse.org');
}

sub run {
    my ($self) = @_;
    my $release_name = "kiosk";
    my $namespace = "kiosk";
    my $helm_values = "kiosk_values.yaml";
    my $helm_chart = get_required_var("HELM_CHART");

    my $set_options = "";
    if (my $image = get_var('CONTAINER_IMAGE_TO_TEST')) {
        my ($repository, $tag) = split(':', $image, 2);
        my $helm_values_image_path = get_required_var('HELM_VALUES_IMAGE_PATH');

        $set_options .= "--set $helm_values_image_path.image.repository=$repository --set $helm_values_image_path.image.tag=$tag";
    }

    select_console 'root-console';
    set_hostname(get_var('HOSTNAME') // 'server');
    setup_static_mm_network('10.0.2.101/24');
    ensure_client_reachable();

    # Permit ssh login as root
    assert_script_run("echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf");
    assert_script_run("systemctl restart sshd");

    # Install the package SUSE certificate
    enter_trup_shell;
    zypper_call("ar --refresh https://download.opensuse.org/repositories/SUSE:/CA/openSUSE_Tumbleweed/SUSE:CA.repo");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("install -y ca-certificates-suse");
    exit_trup_shell;
    check_reboot_changes;


    # # Install helm
    install_k3s();
    set_var('HELM_INSTALL_UPSTREAM', 1);
    install_helm();

    # Get the kiosk_values.yaml
    assert_script_run("curl " . autoinst_url("/data/x11/helm_chart/$helm_values") . " -o $helm_values", 60);
    # Deploy using Helm
    assert_script_run("helm install -n $namespace --create-namespace -f $helm_values $set_options $release_name $helm_chart", timeout => 100);

    # Verify the firefox kiosk container started
    assert_screen("firefox_kiosk", 300);
    assert_and_click("firefox_play_audio");
    # Enable loop play to ensure the "pactl list sink-inputs" can get a verbose list for each active audio stream
    assert_and_click("firefox_loop_play");

    # Notify that the server is ready
    mutex_create("x11_helm_server_ready");

    wait_for_children();
}

1;

