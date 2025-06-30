# SUSE"s openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Deploy X11, pulseaudio, firefox kiosk
#          with Kubernetes Using Helm
# Maintainer: Grace Wang <grace.wang@suse.com>

use warnings;
use strict;
use testapi;
use lockapi;
use base 'x11test';
use mmapi;
use mm_tests;
use x11utils 'turn_off_gnome_screensaver';

# MM network check: try to ping the gateway, and the server
sub ensure_server_reachable {
    assert_script_run('ping -c 1 10.0.2.2');
    assert_script_run('ping -c 1 10.0.2.101');
}

sub run {
    my $self = shift;
    my $helm_server = "10.0.2.101";

    # Setup static NETWORK
    $self->configure_static_ip_nm('10.0.2.102/24');

    x11_start_program('xterm');
    turn_off_gnome_screensaver;

    mutex_wait("x11_helm_server_ready");
    ensure_server_reachable();

    # ssh login to the x11 helm server
    enter_cmd('ssh root@10.0.2.101');
    assert_screen 'ssh-login', 60;
    enter_cmd "yes";
    assert_screen 'password-prompt', 60;
    type_password();
    send_key "ret";
    assert_screen 'ssh-login-ok';

    # Check if pulseaudio service is running
    enter_cmd "export pod_name=`kubectl get pods -n kiosk -o name | cut -d '/' -f 2`";
    enter_cmd "echo \$pod_name";
    enter_cmd("kubectl exec \$pod_name -c pulseaudio -n kiosk -- sh -c 'ps aux'");
    assert_screen("pa-service-running-helm");
    # Check the audio can be played fine from the code level
    enter_cmd("kubectl exec \$pod_name -c pulseaudio -n kiosk -- sh -c 'pactl list sink-inputs'");
    assert_screen("firefox-container-playing-audio");

    # Uninstall the release
    enter_cmd("helm uninstall kiosk --namespace kiosk");
    assert_screen("release-uninstalled");

    # Stop ssh
    enter_cmd "exit";

    # Exit xterm
    send_key "alt-f4";
    assert_screen 'generic-desktop';
}

1;

