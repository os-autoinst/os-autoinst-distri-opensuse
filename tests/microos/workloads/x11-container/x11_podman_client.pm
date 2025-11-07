# SUSE"s openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: podman x11-container
# Summary: install and verify x11 container.
# Maintainer: Grace Wang <grace.wang@suse.com>

use testapi;
use lockapi;
use base 'x11test';
use mmapi;
use x11utils 'turn_off_gnome_screensaver';
use x11test qw(x11_client_preparation stop_containers);

sub run {
    my $self = shift;

    # preparations
    $self->x11_client_preparation();

    # check if pulseaudio service is running
    enter_cmd("podman exec pulseaudio-container ps aux | grep pulseaudio");
    assert_screen("pa-service-running");

    # wait for the server side to play audio from firefox
    sleep 60;
    # check the audio can be played fine from the code level
    enter_cmd("podman exec pulseaudio-container pactl list sink-inputs");
    assert_screen("firefox-container-playing-audio");

    $self->stop_containers();
}

1;

