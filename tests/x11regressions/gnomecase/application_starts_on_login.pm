# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: testcase 5255-1503973: Gnome: Applications starts on login
# Maintainer: xiaojun <xjin@suse.com>

use base "x11regressiontest";
use strict;
use testapi;
use utils;

sub tweak_startupapp_menu {
    my ($self) = @_;
    $self->start_gnome_settings;
    type_string "tweak";
    assert_screen "settings-tweak-selected";
    send_key "ret";
    assert_screen "tweak-tool";
    # increase the default timeout - the switching can be slow
    send_key_until_needlematch "tweak-startapp", "down", 10, 2;
}

sub start_dconf {
    my ($self) = @_;
    $self->start_gnome_settings;
    type_string "dconf";
    assert_screen "settings-dconf";
    send_key "ret";
    if (check_screen("dconf-caution")) {
        assert_and_click "will-be-careful";
    }
}

sub alter_status_auto_save_session {
    my ($self) = @_;
    $self->start_dconf;
    # Old behavior for non SLE15 or non TW
    if (!sle_version_at_least('15') && !leap_version_at_least('15.0')) {
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
        type_string "auto-save-session\n";
    }
    assert_and_click "auto-save-session";
    if (check_screen("changing-scheme-popup")) {
        assert_and_click "auto-save-session-alter-use-default";
        assert_and_click "auto-save-session-true";
        assert_and_click "auto-save-session-apply";
    }
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
}

sub restore_status_auto_save_session {
    my ($self) = @_;
    $self->start_dconf;
    assert_and_click "auto-save-session" unless (sle_version_at_least('15'));
    assert_and_click "auto-save-session-alter-use-default";
    assert_and_click "auto-save-session-apply";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
}

sub run {
    my ($self) = @_;
    #add firefox to startup application
    assert_screen "generic-desktop";
    $self->tweak_startupapp_menu;
    assert_and_click "tweak-startapp-add";
    assert_screen "tweak-startapp-applist";
    if (sle_version_at_least('12-SP2')) {
        assert_and_click "startupApp-searching";
        wait_still_screen;
        assert_screen "focused-on-search";
        type_string "firefox";
        assert_and_click "firefox-searched";
    }
    else {
        send_key_until_needlematch "applicationstart-firefox", "down";
    }
    assert_and_click "tweak-addapp-2startup";
    assert_screen "startapp-firefox-added";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";

    handle_logout;
    handle_login;
    $self->firefox_check_popups;
    assert_screen "firefox-gnome", 90;
    send_key "alt-f4";
    wait_still_screen;
    send_key "ret";
    wait_still_screen;
    assert_screen "generic-desktop";

    #remove firefox from startup application
    $self->tweak_startupapp_menu;
    assert_screen "startapp-firefox-added";
    assert_and_click "startapp-delete";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
    assert_screen "generic-desktop";

    handle_logout;
    handle_login;
    assert_screen "generic-desktop";

    #set auto-save-session;
    ##reference information: start from gnome 3,
    ##for lacking maintainence,
    ##auto-save-session functionality has been abandoned;
    ##current status: just firefox works
    ##so in the future will consider remove openqa code for this session
    # Install dconf-editor for TW
    if (check_var('VERSION', 'Tumbleweed')) {
        select_console('root-console');
        pkcon_quit;
        zypper_call('in dconf-editor');
        select_console('x11');
    }
    $self->alter_status_auto_save_session;

    x11_start_program('firefox');
    wait_still_screen;
    $self->firefox_check_default;
    $self->firefox_check_popups;
    assert_screen "firefox-gnome", 90;
    handle_logout;
    handle_login;
    $self->firefox_check_popups;
    assert_screen "firefox-gnome", 90;
    send_key "alt-f4";
    wait_still_screen;
    send_key "ret";
    wait_still_screen;

    if (sle_version_at_least('12-SP2')) {
        $self->restore_status_auto_save_session;
    }
    else {
        $self->alter_status_auto_save_session;
    }
}

1;
# vim: set sw=4 et:
