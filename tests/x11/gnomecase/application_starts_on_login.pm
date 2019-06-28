# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: testcase 5255-1503973: Gnome: Applications starts on login
# Maintainer: xiaojun <xjin@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_leap is_sle is_tumbleweed);
use x11utils qw(handle_relogin turn_off_gnome_screensaver);

sub tweak_startupapp_menu {
    my ($self) = @_;
    if (is_tumbleweed) {
        x11_start_program 'gnome-tweaks';
    }
    elsif (is_sle('15+')) {
        # tweak-tool entry is not in gnome-control-center of SLE15;
        x11_start_program 'gnome-tweak-tool';
    }
    else {
        $self->start_gnome_settings;
        type_string "tweak";
        assert_screen "settings-tweak-selected";
        send_key "ret";
    }
    assert_screen "tweak-tool";
    # increase the default timeout - the switching can be slow
    send_key_until_needlematch "tweak-startapp", "down", 10, 2;
}

sub start_dconf {
    my ($self) = @_;

    if (is_tumbleweed || is_sle('15+')) {
        # dconf-editor entry is not in gnome-control-center of SLE15;
        x11_start_program 'dconf-editor', target_match => 'will-be-careful';
    }
    else {
        $self->start_gnome_settings;
        type_string "dconf";
        assert_screen "settings-dconf";
        send_key "ret";
        wait_still_screen 2, 4;
    }

    # dconf-editor always show the notice to be careful after the main window
    assert_and_click 'will-be-careful' if check_screen 'will-be-careful';
    assert_screen 'dconf-editor';
}

sub alter_status_auto_save_session {
    my ($self) = @_;
    $self->start_dconf;
    # Old behavior for non SLE15 or non TW
    if (is_sle('<15')) {
        send_key_until_needlematch "dconf-org", "down";
        assert_and_click "unfold";
        send_key_until_needlematch "dconf-org-gnome", "down";
        assert_and_click "unfold";
        send_key_until_needlematch "dconf-gnome-evolution", "down";
        assert_and_click "scroll-down";    #this step aim to work around screen not scroll down automate issue
        send_key_until_needlematch "gnome-session", "down";
    }
    # New behavior for SLE15 and TW
    else {
        send_key 'ctrl-f';
        assert_screen 'dconf-search-bar';
        type_string "auto-save-session\n", max_interval => 200;
    }
    assert_and_click "auto-save-session";
    if (check_screen("changing-scheme-popup", 5)) {
        assert_and_click "auto-save-session-alter-use-default";
        assert_and_click "auto-save-session-true";
        assert_and_click "auto-save-session-apply";
        send_key "alt-f4";
        wait_still_screen 2, 4;
    }
    send_key "alt-f4";
}

sub restore_status_auto_save_session {
    my ($self) = @_;
    $self->start_dconf;
    assert_and_click "auto-save-session";
    if (check_screen("changing-scheme-popup", 5)) {
        assert_and_click "auto-save-session-alter-use-default";
        assert_and_click "auto-save-session-apply";
        send_key "alt-f4";
        wait_still_screen 2, 4;
    }
    send_key "alt-f4";
}

sub run {
    my ($self) = @_;
    assert_screen "generic-desktop";

    # turn off screensaver
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    send_key 'alt-f4';

    #add xterm to startup application
    $self->tweak_startupapp_menu;
    assert_and_click "tweak-startapp-add";
    assert_screen "tweak-startapp-applist";
    if (is_sle('12-SP2+') || is_tumbleweed) {
        assert_and_click "startupApp-searching";
        wait_still_screen 2, 4;
        assert_screen "focused-on-search";
        type_string 'xterm';
        wait_still_screen 2, 4;
    }
    else {
        send_key_until_needlematch "applicationstart-xterm", "down";
    }
    send_key_until_needlematch 'tweak-addapp-2startup', 'tab';
    send_key 'ret';
    assert_screen "startapp-xterm-added";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";

    handle_relogin;
    assert_screen 'xterm';
    send_key "alt-f4";
    wait_still_screen;
    send_key "ret";
    wait_still_screen;
    assert_screen "generic-desktop";

    #remove xterm from startup application
    $self->tweak_startupapp_menu;
    assert_screen "startapp-xterm-added";
    assert_and_click "startapp-delete";
    wait_still_screen 2, 4;
    send_key "alt-f4";
    assert_screen "generic-desktop";

    handle_relogin;
    assert_screen "generic-desktop";

    # save session
    $self->alter_status_auto_save_session;
    x11_start_program('xterm');
    assert_screen 'xterm';
    handle_relogin;
    wait_still_screen;
    send_key 'alt-tab';    # select xterm if unselected
    assert_screen 'xterm';
    send_key 'alt-f4';
    wait_still_screen 2, 4;

    if (is_sle('12-SP2+')) {
        $self->restore_status_auto_save_session;
    }
    else {
        $self->alter_status_auto_save_session;
    }
}

1;
