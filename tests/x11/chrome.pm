# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: chrome-chrome-stable
# Summary: GOOGLE Chrome: attempt to install and run google chrome
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use utils;

sub install_google_repo_key {
    become_root;
    assert_script_run "rpm --import https://dl.google.com/linux/linux_signing_key.pub";
    # validate it's properly installed
    script_run "rpm -qi gpg-pubkey-7fac5991-*";
    assert_screen 'google-key-installed';
}

sub avoid_async_keyring_popups {
    x11_start_program('google-chrome --password-store=basic', target_match => 'chrome-default-browser-query');
}

sub preserve_privacy_of_non_human_openqa_workers {
    # we like to preserve the privacy of the non-human openqa workers ;-)
    assert_and_click 'chrome-do_not_send_data' if match_has_tag 'chrome-default-browser-query-send-data';
}

sub run {
    my $arch = is_i586 ? 'i386' : 'x86_64';
    my $chrome_url = "https://dl.google.com/linux/direct/google-chrome-stable_current_$arch.rpm";
    select_console('x11');
    mouse_hide;
    x11_start_program('xterm');
    install_google_repo_key;
    zypper_call "in $chrome_url";
    save_screenshot;
    # closing xterm
    send_key "alt-f4";
    avoid_async_keyring_popups;
    preserve_privacy_of_non_human_openqa_workers;
    assert_and_click 'chrome-default-browser-query';
    assert_screen [qw(google-chrome-main-window google-chrome-dont-sign-in)];
    click_lastmatch if match_has_tag('google-chrome-dont-sign-in');
    wait_screen_change { send_key 'ctrl-l' };
    enter_cmd 'about:';
    assert_screen 'google-chrome-about';
    send_key 'alt-f4';
}

1;
