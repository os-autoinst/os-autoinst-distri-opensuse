# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

#testcase 5255-1503973: Gnome: Applications starts on login

sub tweak_startupapp_menu {
    send_key "super";
    wait_still_screen;
    type_string "settings", 1;    #Use '1' to give gnome-shell enough time to search settings module; Otherwise slow worker will cause failed result.
    send_key "ret";
    assert_screen "gnome-settings";
    type_string "tweak";
    send_key "ret";
    assert_screen "tweak-tool";
    send_key_until_needlematch "tweak-startapp", "down";
}

sub logout_and_login {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "logout";
    send_key "ret";
    assert_screen "displaymanager";
    send_key "ret";
    type_string "$password";
    send_key "ret";
}

sub alter_status_auto_save_session {
    send_key "super";
    type_string "settings", 1;    #Use '1' to give gnome-shell enough time to search settings module; Otherwise slow worker will cause failed result.
    send_key "ret";
    assert_screen "gnome-settings";
    type_string "dconf";
    send_key "ret";
    send_key_until_needlematch "dconf-org", "down";
    assert_and_click "unfold";
    send_key_until_needlematch "dconf-org-gnome", "down";
    assert_and_click "unfold";
    send_key_until_needlematch "dconf-gnome-evolution", "down";
    assert_and_click "scroll-down";    #this step aim to work around screen not scroll down automate issue
    send_key_until_needlematch "gnome-session", "down";
    assert_and_click "auto-save-session";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
}

sub run() {
    my $self = shift;

    #add firefox to startup application
    tweak_startupapp_menu;
    assert_and_click "tweak-startapp-add";
    assert_screen "tweak-startapp-applist";
    send_key_until_needlematch "applicationstart-firefox", "down";
    assert_and_click "tweak-addapp-button";
    assert_screen "startapp-firefox-added";
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";

    logout_and_login;
    assert_screen "application-running-firefox";
    send_key "alt-f4";

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
    ##For got information: start from gnome 3,
    ##for lacking maintainence,
    ##auto-save-session functionality has been abandoned;
    ##current status: just firefox works
    ##so in the future will consider remove openqa code for this session
    alter_status_auto_save_session;

    assert_and_click "application-menu";
    assert_and_click "application-menu-firefox";
    wait_still_screen;
    assert_screen "firefox-loaded";
    logout_and_login;
    assert_screen "session-running-firefox";
    send_key "alt-f4";

    alter_status_auto_save_session;
}

1;
# vim: set sw=4 et:
