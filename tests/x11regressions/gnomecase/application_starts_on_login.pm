# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use strict;
use testapi;

#testcase 5255-1503973: Gnome: Applications starts on login

sub tweak_startupapp_menu {
    send_key "super";
    wait_still_screen;
    type_string "settings", 1;    #Use '1' to give gnome-shell enough time to search settings module; Otherwise slow worker will cause failed result.
    assert_and_click "settings";
    assert_screen "gnome-settings";
    type_string "tweak";
    assert_screen "settings-tweak-selected";
    send_key "ret";
    assert_screen "tweak-tool";
    send_key_until_needlematch "tweak-startapp", "down";
}

sub logout_and_login {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "logout-system";
    wait_still_screen;
    send_key "ret";
    assert_screen "displaymanager";
    send_key "ret";
    assert_screen "originUser-login-dm";
    type_string "$password";
    send_key "ret";
}

sub alter_status_auto_save_session {
    send_key "super";
    wait_still_screen;
    type_string "settings", 1;    #Use '1' to give gnome-shell enough time to search settings module; Otherwise slow worker will cause failed result.
    assert_and_click "settings";
    assert_screen "gnome-settings";
    type_string "dconf";
    assert_screen "settings-dconf";
    send_key "ret";
    if (check_screen("dconf-caution")) {
        assert_and_click "will-be-careful";
    }
    send_key_until_needlematch "dconf-org", "down";
    assert_and_click "unfold";
    send_key_until_needlematch "dconf-org-gnome", "down";
    assert_and_click "unfold";
    send_key_until_needlematch "dconf-gnome-evolution", "down";
    assert_and_click "scroll-down";    #this step aim to work around screen not scroll down automate issue
    send_key_until_needlematch "gnome-session", "down";
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
    send_key "super";
    wait_still_screen;
    type_string "settings", 1;    #Use '1' to give gnome-shell enough time to search settings module; Otherwise slow worker will cause failed result.
    assert_and_click "settings";
    assert_screen "gnome-settings";
    type_string "dconf", 1;
    assert_screen "settings-dconf";
    send_key "ret";
    if (check_screen("dconf-caution")) {
        assert_and_click "will-be-careful";
    }
    assert_and_click "auto-save-session";
    assert_and_click "auto-save-session-alter-use-default";
    assert_and_click "auto-save-session-apply";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
}

sub run() {
    my $self = shift;

    #add firefox to startup application
    assert_screen "generic-desktop";
    tweak_startupapp_menu;
    assert_and_click "tweak-startapp-add";
    assert_screen "tweak-startapp-applist";
    if (get_var("SP2ORLATER")) {
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

    logout_and_login;
    assert_screen "firefox-gnome", 90;
    send_key "alt-f4";
    wait_still_screen;
    send_key "ret";
    wait_still_screen;
    assert_screen "generic-desktop";

    #remove firefox from startup application
    tweak_startupapp_menu;
    assert_screen "startapp-firefox-added";
    assert_and_click "startapp-delete";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
    assert_screen "generic-desktop";

    logout_and_login;
    assert_screen "generic-desktop";

    #set auto-save-session;
    ##reference information: start from gnome 3,
    ##for lacking maintainence,
    ##auto-save-session functionality has been abandoned;
    ##current status: just firefox works
    ##so in the future will consider remove openqa code for this session
    alter_status_auto_save_session;

    x11_start_program("firefox");
    wait_still_screen;
    assert_screen "firefox-gnome", 90;
    logout_and_login;
    assert_screen "firefox-gnome", 90;
    send_key "alt-f4";
    wait_still_screen;
    send_key "ret";
    wait_still_screen;

    if (get_var("SP2ORLATER")) {
        restore_status_auto_save_session;
    }
    else {
        alter_status_auto_save_session;
    }
}

1;
# vim: set sw=4 et:
