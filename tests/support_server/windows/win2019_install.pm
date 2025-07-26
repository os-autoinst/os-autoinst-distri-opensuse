# SUSE's openQA tests
#
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot and install Windows server 2019
# Maintainer: mmartins <mmartins@suse.com>

use base 'windowsbasetest';
use testapi;
use mmapi;

sub run {
    #sometimes windows spend more time to boot, added "start waiting"
    assert_and_click "start", timeout => 120;

    assert_and_click "install_now";
    assert_and_click "skip_registration";
    assert_and_click "windows_server_stand-desktop";
    assert_and_click "windows_server_stand";
    assert_and_click "windows_license_terms_accept";
    assert_and_click "windows_license_terms_next";
    assert_and_click "windows_install";

    assert_screen 'windows-disk-partitioning';
    send_key 'alt-l';    # load disk driver from VMDP-2.5.2 ISO
    assert_screen 'windows-load-driver';
    send_key 'alt-b';    # browse button
    send_key 'c';
    save_screenshot;
    send_key 'c';    # go to second CD drive with drivers
    send_key 'right';    # choose win2019 INF files
    sleep 0.5;
    send_key 'down';
    send_key 'right';    # ok
    sleep 0.5;
    send_key 'down';
    send_key 'down';
    sleep 0.5;
    send_key 'ret';
    wait_still_screen stilltime => 3, timeout => 10;
    send_key 'shift-down';    # select all drivers
    send_key 'alt-n';
    assert_and_click "windows_format_new";
    assert_and_click "windows-size";
    assert_and_click "windows-additional-partitions";
    assert_and_click "windows-next-install";
    assert_and_click "windows-admin-login2", timeout => 600;
    type_string "N0tS3cr3t@";
    send_key "tab";
    wait_screen_change { type_string "N0tS3cr3t@" };
    send_key "ret";
    assert_and_click "windows-admin-finish";
    assert_screen "windows-installed-ok";
}

1;
