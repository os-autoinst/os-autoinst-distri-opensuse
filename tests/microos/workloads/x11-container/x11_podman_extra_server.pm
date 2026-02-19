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

use base 'x11test';
use base "opensusebasetest";
use testapi;
use lockapi;
use mmapi;
use utils qw(set_hostname permit_root_ssh);

sub run {
    my $self = shift;

    # preparations
    select_console 'root-console';
    $self->x11_server_preparation();

    # download custom wallboard
    assert_script_run("curl -o wallpaper.png https://hackweek.opensuse.org/img/HW25/SUSE_Hackweek25_Wallpaper_widescreen.png");

    # create the Xmodmap to test remap 'a'>'b' and 'b'>'a'
    my $custom_modmap = "/root/kiosk.Xmodmap";
    assert_script_run("touch $custom_modmap");
    assert_script_run("echo keycode  38 = b B >> $custom_modmap");
    assert_script_run("echo keycode  56 = a A >> $custom_modmap");

    # start X11 container
    my $containerpath = get_var('CONTAINER_IMAGE_TO_TEST', 'registry.suse.de/suse/sle-15-sp6/update/cr/totest/images/suse/kiosk/xorg:notaskbar');
    assert_script_run("podman pull $containerpath --tls-verify=false", 300);
    assert_script_run("podman run --privileged -d --pod wallboard-pod -e XAUTHORITY=/home/user/xauthority/.xauth -v xauthority:/home/user/xauthority:rw -v xsocket:/tmp/.X11-unix:rw -v /run/udev/data:/run/udev/data:rw --name x11-init-container --security-opt=no-new-privileges  -v /root/wallpaper.png:/usr/share/wallpapers/SLEdefault/contents/images/1920x1080.png:ro -v /root/kiosk.Xmodmap:/root/.Xmodmap:ro $containerpath");
    # verify the x11 server container started
    assert_screen "icewm_custom_wallboard";
    send_key "super";
    assert_and_click "menu-appear";
    enter_cmd "aaabbb";
    assert_screen "remap_key_success";
    send_key "alt-f4";

    # Notify that the server is ready
    mutex_create("x11_container_ready");

    # verify the firefox kiosk container started
    assert_screen("firefox_kiosk_js2", timeout => 120);
    assert_and_click "jetstream-start-test";

    assert_screen("firefox-js2-score", timeout => 600);
    mutex_create("x11_js_done_ready");

    wait_for_children();
}
sub post_run_hook { }

1;

