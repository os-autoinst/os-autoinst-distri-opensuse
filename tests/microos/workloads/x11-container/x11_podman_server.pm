# SUSE"s openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: podman x11-container
# Summary: install and verify x11 container.
# Maintainer: Grace Wang <grace.wang@suse.com>

use base 'x11test';
use testapi;
use lockapi;
use mmapi;
use utils qw(set_hostname permit_root_ssh);

sub run {
    my $self = shift;

    # preparations
    $self->x11_server_preparation();

    # start X11 container
    my $containerpath = get_var('CONTAINER_IMAGE_TO_TEST', 'registry.suse.de/suse/sle-15-sp6/update/cr/totest/images/suse/kiosk/xorg:notaskbar');
    assert_script_run("podman pull $containerpath --tls-verify=false", 300);
    assert_script_run("podman run --privileged -d --pod wallboard-pod -e XAUTHORITY=/home/user/xauthority/.xauth -v xauthority:/home/user/xauthority:rw -v xsocket:/tmp/.X11-unix:rw -v /run/udev/data:/run/udev/data:rw --name x11-init-container --security-opt=no-new-privileges $containerpath");
    # verify the x11 server container started
    assert_screen "icewm_wallboard";

    # Notify that the server is ready
    mutex_create("x11_container_ready");

    # verify the firefox kiosk container started
    assert_screen("firefox_kiosk", 300);
    assert_and_click "firefox_play_audio";

    wait_for_children();
}
sub post_run_hook { }

1;

