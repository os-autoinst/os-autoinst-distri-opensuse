# SUSE"s openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: podman x11-container
# Summary: install and verify x11 container.
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

    # Setup static NETWORK
    $self->configure_static_ip_nm('10.0.2.102/24');

    x11_start_program('xterm');
    turn_off_gnome_screensaver;

    mutex_wait("x11_container_ready");
    ensure_server_reachable();

    # ssh login to the x11 server
    enter_cmd('ssh root@10.0.2.101');
    assert_screen 'ssh-login', 60;
    enter_cmd "yes";
    assert_screen 'password-prompt', 60;
    type_password();
    send_key "ret";
    assert_screen 'ssh-login-ok';

    my $opts = "-e DISPLAY=:0 -e XAUTHORITY=/home/user/xauthority/.xauth -e PULSE_SERVER=/var/run/pulse/native -v xauthority:/home/user/xauthority:rw -v pasocket:/var/run/pulse/ -v xsocket:/tmp/.X11-unix:rw";
    # pulseaudio image url and firefox kiosk url are joined together by a space
    # split the string by space
    my ($pacontainerpath, $ffcontainerpath) = split(/\s+/, get_var("CONTAINER_IMAGE_TO_TEST", 'registry.suse.de/suse/sle-15-sp6/update/cr/totest/images/suse/pulseaudio:17 registry.suse.de/suse/sle-15-sp6/update/cr/totest/images/suse/kiosk-firefox-esr:128.8'));
    # start pulseaudio container
    enter_cmd("podman pull $pacontainerpath --tls-verify=false", 300);
    assert_screen("podman-pa-pull-done");
    enter_cmd("podman run -d --pod wallboard-pod $opts -v /run/udev/data:/run/udev/data:rw --name pulseaudio-container --privileged $pacontainerpath bash -c 'chown root:audio /dev/snd/*; /usr/bin/pulseaudio -vvv --log-target=stderr'");
    assert_screen("podman-pa-run");

    # start firefox container
    enter_cmd("podman pull $ffcontainerpath --tls-verify=false", 300);
    assert_screen("podman-ff-pull-done");
    # URL https://freesound.org/people/kevp888/sounds/796468/ can be used for testing
    # Since it doesn't have ads and require login before playing audio
    enter_cmd("podman run -d --pod wallboard-pod -e URL=https://freesound.org/people/kevp888/sounds/796468/ $opts --user 1000 --name wallboard-container --security-opt=no-new-privileges $ffcontainerpath");
    assert_screen("podman-firefox-run");

    # check if pulseaudio service is running
    enter_cmd("podman exec pulseaudio-container ps aux | grep pulseaudio");
    assert_screen("pa-service-running");

    # wait for the server side to play audio from firefox
    sleep 60;
    # check the audio can be played fine from the code level
    enter_cmd("podman exec pulseaudio-container pactl list sink-inputs");
    assert_screen("firefox-container-playing-audio");

    # stop container
    enter_cmd("podman stop wallboard-container");
    assert_screen("wallboard-container-stopped");
    enter_cmd("podman stop pulseaudio-container");
    assert_screen("pa-container-stopped");
    enter_cmd("podman stop x11-init-container");
    assert_screen("x11-container-stopped");

    # stop ssh
    enter_cmd "exit";

    # exit xterm
    send_key "alt-f4";
    assert_screen 'generic-desktop';
}

1;

