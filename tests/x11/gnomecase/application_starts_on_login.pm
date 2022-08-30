# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-tweaks gnome-tweak-tool dconf-editor
# Summary: testcase 5255-1503973: Gnome: Applications starts on login
# - Checks if machine is at a generic desktop
# - Launches a xterm
# - Turns off screensaver
# - Closes xterm
# - Call gnome-tweak (gnome-tweak-tool on sle15+) and increase default timeout
# - Add xterm to startup applications list by using gnome-tweaks and "Startup
# Applications" option
# - Relogin by calling "handle_relogin" function
# - Checks if xterm started up
# - Kill xterm and check for generic desktop
# - Remove xterm from startup applications list using gnome-tweal
# - Relogin by calling "handle_relogin" again
# - Check for generic desktop
# - Call dconf; on sle<15, navigate until "gnome-session" is found, press down
# - On sle<15sp2, look for auto-save-session option and toggle it
# - Check for options "auto-save-session-alter-use-default", "auto-save-session-true";
# "auto-save-session-apply", if available, click it
# - Close dconf
# - Start xterm
# - Relogin by calling "handle_relogin"
# - Send alt-tab
# - Check for xterm
# - Close xterm
# - Call dconf and rollback changes for save session

# Maintainer: xiaojun <xjin@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use version_utils qw(is_leap is_opensuse is_sle is_tumbleweed);
use x11utils qw(handle_relogin turn_off_gnome_screensaver);

sub tweak_startupapp_menu {
    my ($self) = shift;

    $self->start_gnome_tweak_tool;
    # increase the default timeout - the switching can be slow
    send_key_until_needlematch "tweak-startapp", "down", 11, 2;
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
        my $autosavesession = "auto-save-session";
        if (!is_opensuse || !is_aarch64) {
            # the first occurence is pre-selected on aarch64 openSUSE and '\n' would open the pop-up
            $autosavesession .= "\n";
        }
        type_string "$autosavesession", max_interval => 200;
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
    assert_screen [qw(xterm xterm-without-focus)];
    if (match_has_tag 'xterm-without-focus') {
        record_soft_failure("poo#66099 - xterm not focused with GNOME 3.36+ https://gitlab.gnome.org/GNOME/mutter/-/issues/1207");
        # focus it
        click_lastmatch;
        assert_screen 'xterm';
    }
    send_key "esc";
    assert_and_click "xterm-close-window";
    assert_screen "generic-desktop";

    #remove xterm from startup application
    $self->tweak_startupapp_menu;
    assert_screen "startapp-xterm-added";
    assert_and_click "startapp-delete";
    wait_still_screen 2, 4;
    send_key "alt-f4";
    assert_screen "generic-desktop";

    handle_relogin;

    # save session, available only for GNOME<3.34.2, see bsc#1158851
    if (is_sle('<15-sp2') || is_leap('<15.2')) {
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
}

1;
