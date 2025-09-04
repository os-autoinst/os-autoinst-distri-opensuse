# SUSE"s openQA tests
#
# Copyright SUSE LLC
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


my $base_url = autoinst_url;
my $audio_html = <<_EOF_;
<!DOCTYPE html>
<html>
<head>
  <title>Sample audio file</title>
</head>
<body>
  <audio loop controls> <!-- autoplay is blocked in modern browsers -->
    <source src="$base_url/data/bar.wav" type="audio/wav">
    Your browser does not support the audio tag.
  </audio>
</body>
</html>
_EOF_

sub run {
    my ($self) = @_;

    select_serial_terminal;
    my $helm_chart = get_required_var("HELM_CHART");
    my $helm_values = autoinst_url("/data/containers/helm/kiosk/values.yaml");

    # Install helm
    install_helm();

    # Run an nginx container with a test page and wait for it
    assert_script_run("kubectl create configmap audio-html-config --from-literal=audio.html='$audio_html'");
    assert_script_run("kubectl apply -f " . autoinst_url("/data/containers/helm/kiosk/nginx.yaml"));
    assert_script_run("kubectl wait --for=condition=Ready pod/nginx-test --timeout=60s");

    # login to graphical tty before starting
    select_console 'root-console';

    # Deploy using Helm
    select_serial_terminal;
    helm_install_chart($helm_chart, $helm_values, "kiosk");

    # Verify the firefox kiosk container started
    select_console 'root-console';
    assert_screen 'firefox_kiosk', 300;
    assert_and_click 'firefox_play_audio';

    select_serial_terminal;

    my $pod_name = script_output("kubectl get pods -o name | grep kiosk | cut -d '/' -f 2");

    validate_script_output("kubectl exec $pod_name -c pulseaudio -- sh -c 'ps aux'", qr/^pulse.*pulseaudio$/m), fail_message => 'pulseaudio is not running';
    validate_script_output("kubectl exec $pod_name -c pulseaudio -- sh -c 'pactl list sink-inputs'", qr/application.name = "Firefox"/m && qr/application.process.host = "$pod_name"/m), fail_message => 'firefox did not allocate an audio sink';

    assert_script_run("helm uninstall kiosk");
}

1;
