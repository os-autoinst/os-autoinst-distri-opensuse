# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1436079: Firefox: Password Management
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open firefox preferences
#   - Enter security preferences
#   - Select "Use a master password"
#   - Fill and confirm with password "firefox_test"
# - Restart firefox
# - Open url
# "https://www-archive.mozilla.org/quality/browser/front-end/testcases/wallet/login.html"
# - Access page with user and password
# - Handle password remembering confirmation
# - Open
# "https://www-archive.mozilla.org/quality/browser/front-end/testcases/wallet/login.html"
# once more
# - Check that username/password were auto-filled
# - Open firefox preferences -> security -> saved passwords
# - Check that passwords were saved
# - Clear saved passwords
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use version_utils;

sub run {
    my ($self) = @_;

    my $masterpw = "firefox_test";
    my $mozlogin = "https://www-archive.mozilla.org/quality/browser/front-end/testcases/wallet/login.html";

    # Start Firefox
    $self->start_firefox_with_profile;

    $self->firefox_preferences;
    assert_and_click('firefox-passwd-security');
    send_key_until_needlematch('firefox-primary-passwd-selected', 'alt-shift-u', 4, 1);
    send_key 'spc';
    assert_screen('firefox-passwd-master_setting');
    type_string $masterpw, 150;
    send_key "tab";
    type_string $masterpw, 150;
    wait_still_screen 2, 4;
    send_key 'ret';
    assert_and_click('firefox-passwd-success');

    #Restart firefox
    $self->restart_firefox;

    $self->firefox_open_url($mozlogin);

    assert_and_click('firefox-passwd-input_username');
    type_string "squiddy";
    send_key "tab";
    type_string "calamari";
    send_key "ret";
    wait_still_screen(2);
    assert_and_click('firefox-passwd-confirm_remember');
    assert_screen('firefox-passwd-confirm_master_pw');
    enter_cmd $masterpw. "";

    $self->firefox_open_url($mozlogin);
    assert_screen('firefox-passwd-auto_filled');

    $self->firefox_preferences;
    assert_and_click('firefox-passwd-security');
    send_key_until_needlematch 'firefox-saved-logins-button', 'alt-shift-l', 6, 1;
    wait_still_screen 3;
    send_key 'spc';
    assert_screen('firefox-passwd-saved');
    assert_and_click('firefox-saved-logins-remove');
    send_key 'spc';
    send_key_until_needlematch('firefox-passwd-auto_filled', 'ctrl-w', 4, 2);
    send_key 'f5';
    assert_screen('firefox-passwd-removed');

    # Exit
    $self->exit_firefox;
}
1;
