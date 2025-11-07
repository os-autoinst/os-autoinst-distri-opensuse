# SUSE"s openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: podman x11-container
# Summary: install and verify x11 container
#          test the custom wallpaper
#          test remap keys
#          Load a benchmark (such as https://browserbench.org/JetStream2.0/)
#          validate that it completes, and record the output
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

    # wait for server side finish the benchmark testing
    mutex_wait("x11_js_done_ready");

    # stop containers
    $self->stop_containers();
}

1;

