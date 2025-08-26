# SUSE"s openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Deploy X11, pulseaudio, firefox kiosk
#          with Kubernetes Using Helm
#
# Initial design: Grace Wang <grace.wang@suse.com>
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils;
use containers::helm;
use containers::k8s qw(install_helm);

sub run {
    my ($self) = @_;

    select_serial_terminal;
    my $helm_chart = get_required_var("HELM_CHART");
    my $helm_values = autoinst_url("/data/containers/kiosk_helm_values.yaml");

    # Install helm
    set_var('HELM_INSTALL_UPSTREAM', 1);
    install_helm();

    # login to graphical tty before starting
    select_console 'root-console';

    # Deploy using Helm
    select_serial_terminal;
    helm_install_chart($helm_chart, $helm_values, "kiosk");

    # Verify the firefox kiosk container started
    select_console 'root-console';
    assert_screen("firefox_kiosk", 300);
    assert_and_click("firefox_play_audio");
    # Enable loop play to ensure the "pactl list sink-inputs" can get a verbose list for each active audio stream
    assert_and_click("firefox_loop_play");

    select_serial_terminal;

    my $pod_name = script_output("kubectl get pods -o name | cut -d '/' -f 2");

    # check if pulseaudio is running
    validate_script_output("kubectl exec $pod_name -c pulseaudio -- sh -c 'ps aux'", qr/^pulse.*pulseaudio$/m);

    # check if firefox allocates a sink
    validate_script_output("kubectl exec $pod_name -c pulseaudio -- sh -c 'pactl list sink-inputs'", qr/application.name = "Firefox"/m && qr/application.process.host = "$pod_name"/m);

    assert_script_run("helm uninstall kiosk");
}

1;
