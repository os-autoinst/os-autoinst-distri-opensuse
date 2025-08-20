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
use containers::helm;
use containers::k8s;
use transactional;
use serial_terminal;

# MM network check: try to ping the gateway, the client and the internet
sub ensure_client_reachable {
    assert_script_run('ping -c 1 10.0.2.2');
    # assert_script_run('ping -c 1 10.0.2.102');
    assert_script_run('curl conncheck.opensuse.org');
}

sub run {
    my ($self) = @_;
    my $release_name = "kiosk";
    my $helm_values = autoinst_url("/data/x11/helm_chart/kiosk_values.yaml");
    my $helm_chart = get_required_var("HELM_CHART");

    select_serial_terminal;

    set_hostname(get_var('HOSTNAME') // 'server');
    setup_static_mm_network('10.0.2.101/24');
    ensure_client_reachable();

    # Install the package SUSE certificate
    enter_trup_shell;
    zypper_call("ar --refresh https://download.opensuse.org/repositories/SUSE:/CA/openSUSE_Tumbleweed/SUSE:CA.repo");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("install -y ca-certificates-suse");
    exit_trup_shell;
    check_reboot_changes;

    # Install helm
    install_k3s();
    set_var('HELM_INSTALL_UPSTREAM', 1);
    install_helm();

    # Deploy using Helm
    helm_install_chart($helm_chart, $helm_values, $release_name);

    select_console 'root-console';

    # Verify the firefox kiosk container started
    assert_screen("firefox_kiosk", 300);
    assert_and_click("firefox_play_audio");
    # Enable loop play to ensure the "pactl list sink-inputs" can get a verbose list for each active audio stream
    assert_and_click("firefox_loop_play");

    select_serial_terminal;

    my $pod_name = script_output("kubectl get pods -o name | cut -d '/' -f 2");
    validate_script_output("kubectl exec $pod_name -c pulseaudio -- sh -c 'ps aux'", qr/^pulse.*pulseaudio$/m);
    validate_script_output("kubectl exec $pod_name -c pulseaudio -- sh -c 'pactl list sink-inputs'", qr/application.name = "Firefox"/m && qr/application.process.host = "$pod_name"/m);

    assert_script_run("helm uninstall kiosk");
}

1;

