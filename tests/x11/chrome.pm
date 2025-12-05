# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: chrome-chrome-stable
# Summary: GOOGLE Chrome: attempt to install and run google chrome
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use testapi;
use Utils::Architectures;
use utils;
use x11utils qw(default_gui_terminal close_gui_terminal);

sub install_google_repo_key {
    become_root;
    assert_script_run "rpm --import https://dl.google.com/linux/linux_signing_key.pub";
    # validate it's properly installed
    assert_script_run "rpm -qi gpg-pubkey-d38b4796-*";
}

sub avoid_async_keyring_popups {
    x11_start_program('google-chrome --password-store=basic', target_match => [qw(chrome-default-browser-query authentication-required)]);
    if (match_has_tag 'authentication-required') {
        type_password;
        assert_and_click "unlock";
        assert_screen "chrome-default-browser-query";
    }
}

sub preserve_privacy_of_non_human_openqa_workers {
    # we like to preserve the privacy of the non-human openqa workers ;-)
    assert_and_click 'chrome-do_not_send_data' if match_has_tag 'chrome-default-browser-query-send-data';
}

sub click_ad_privacy_feature {
    assert_and_click 'google-chrome-ad-privacy-feature-more';
    assert_and_click 'google-chrome-ad-privacy-feature-no';
    if (check_screen 'google-chrome-ad-privacy-feature-more', 5) {
        assert_and_click 'google-chrome-ad-privacy-feature-more';
    }
    assert_and_click 'google-chrome-ad-privacy-feature-ok';
}

sub run {
    my $arch = is_i586 ? 'i386' : 'x86_64';
    my $chrome_url = "https://dl.google.com/linux/direct/google-chrome-stable_current_$arch.rpm";
    select_console('x11');
    mouse_hide;
    x11_start_program(default_gui_terminal);
    install_google_repo_key;
    zypper_call "in $chrome_url";
    save_screenshot;
    close_gui_terminal;
    avoid_async_keyring_popups;
    preserve_privacy_of_non_human_openqa_workers;
    assert_and_click 'chrome-default-browser-query';
    assert_screen [qw(google-chrome-main-window google-chrome-dont-sign-in)];
    click_lastmatch if match_has_tag('google-chrome-dont-sign-in');
    click_ad_privacy_feature;
    wait_screen_change { send_key 'ctrl-l' };
    enter_cmd 'about:';
    assert_screen [qw(google-chrome-about make-chrome-faster)];
    if (match_has_tag 'make-chrome-faster') {
        click_lastmatch;
        assert_screen 'google-chrome-about';
    }
    send_key 'alt-f4';
}

1;
