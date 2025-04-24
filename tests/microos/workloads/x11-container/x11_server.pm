# SUSE"s openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: podman x11-container
# Summary: install and verify x11 container.
# Maintainer: Grace Wang <grace.wang@suse.com>

use base 'consoletest';
use warnings;
use strict;
use testapi;
use lockapi;
use mmapi;
use utils qw(set_hostname permit_root_ssh);
use mm_network 'setup_static_mm_network';

# MM network check: try to ping the gateway, the client and the internet
sub ensure_client_reachable {
    assert_script_run('ping -c 1 10.0.2.2');
    assert_script_run('ping -c 1 10.0.2.102');
    assert_script_run('curl conncheck.opensuse.org');
}

sub x11_preparation {

    # create volume
    assert_script_run("podman volume create xauthority");
    assert_script_run("podman volume create xsocket");
    assert_script_run("podman volume create pasocket");

    # create a pod
    assert_script_run("podman pod create --name wallboard-pod");
}


sub run {
    my ($self) = @_;

    select_console 'root-console';
    set_hostname(get_var('HOSTNAME') // 'server');
    setup_static_mm_network('10.0.2.101/24');
    ensure_client_reachable();

    # Permit ssh login as root
    assert_script_run("echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf");
    assert_script_run("systemctl restart sshd");

    assert_script_run "chmod a+rw /dev/snd/*";

    # preparations
    x11_preparation();

    # start X11 container
    my $containerpath = get_var('CONTAINER_IMAGE_TO_TEST', 'registry.suse.de/suse/sle-15-sp6/update/cr/totest/images/suse/xorg:latest');
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

1;

