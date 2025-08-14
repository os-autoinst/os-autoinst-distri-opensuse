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

my $masterpw = "Firefox_test123!@#";

sub confirm_master_pw {
    enter_cmd $masterpw. "" if (check_screen('firefox-passwd-confirm_master_pw', 20));
}

# Renew the function to in case of FIPs mode,
# we need to signin again with master password
sub restart_firefox_new {
    my ($self, $cmd, $url) = @_;
    $url ||= '/home';
    # exit firefox properly
    wait_still_screen 2;
    $self->exit_firefox_common;
    assert_script_run('time wait $(pidof firefox)');
    enter_cmd "$cmd";
    enter_cmd "firefox $url >>firefox.log 2>&1 &";
    $self->firefox_check_default;
    confirm_master_pw if (get_var('FIPS_ENABLED') || get_var('FIPS'));
    assert_screen 'firefox-url-loaded';
}

sub run {
    my ($self) = @_;

    my $mozlogin = "https://www-archive.mozilla.org/quality/browser/front-end/testcases/wallet/login.html";

    # Start Firefox
    $self->start_firefox_with_profile;

    # until is 128 version on all versions
    send_key 'alt-tab';
    wait_still_screen 1;
    my $version = script_output q(firefox --version|awk -F "[ .]" '{print $3}');
    my $key = ($version >= 128) ? 'd' : 'l';
    send_key 'alt-tab';
    wait_still_screen 1;

    $self->firefox_preferences;
    assert_and_click('firefox-passwd-security');
    send_key_until_needlematch([qw(firefox-primary-passwd-selected firefox-passwd-master_setting)], 'alt-shift-u', 4, 2);
    if (check_screen('firefox-passwd-master_setting', 3)) {
        assert_and_click('firefox-passwd-master_setting');
    }
    assert_and_click("firefox-enter-new-password");
    # We should use strong password due to bsc#1208951
    type_string $masterpw, 150;
    send_key "tab";
    type_string $masterpw, 150;
    wait_still_screen 2, 4;
    send_key 'ret';
    assert_and_click('firefox-passwd-success');

    #Restart firefox
    $self->restart_firefox_new;

    $self->firefox_open_url($mozlogin);
    assert_and_click('firefox-passwd-input_username');
    type_string "squiddy";
    send_key "tab";
    type_string "calamari";
    assert_and_click('firefox-passwd-login');
    wait_still_screen(2);
    assert_and_click('firefox-passwd-confirm_remember');
    confirm_master_pw;
    $self->firefox_open_url($mozlogin, assert_loaded_url => 'firefox-passwd-auto_filled');

    $self->firefox_preferences;
    assert_and_click('firefox-passwd-security');
    if ($version >= 128) {
        # jump to logins, alt-shift-d does not rotate between multiple places :(
        wait_still_screen(3);
        send_key 'alt-shift-f';
        send_key 'alt-shift-f';
        send_key "alt-shift-$key";
    }
    send_key_until_needlematch 'firefox-saved-logins-button', "alt-shift-$key", 6, 2;
    wait_still_screen 3;
    send_key 'spc';
    assert_screen('firefox-passwd-saved');
    assert_and_click('firefox-saved-logins-remove');
    wait_still_screen 1;
    send_key 'spc';
    send_key_until_needlematch('firefox-passwd-auto_filled', 'ctrl-tab', 4, 2);
    send_key 'f5';
    assert_screen('firefox-passwd-removed');

    # Exit
    $self->exit_firefox;
}
1;
