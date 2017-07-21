# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436079: Firefox: Password Management
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run {
    my ($self) = @_;

    mouse_hide(1);

    my $masterpw = "firefox_test";
    my $mozlogin = "https://www-archive.mozilla.org/quality/browser/front-end/testcases/wallet/login.html";

    # Clean and Start Firefox
    $self->start_firefox;

    send_key "alt-e";
    wait_still_screen 3;
    send_key "n";
    assert_and_click('firefox-passwd-security');

    send_key "alt-shift-u";

    assert_screen('firefox-passwd-master_setting', 30);

    type_string $masterpw;
    send_key "tab";
    type_string $masterpw;
    for my $i (1 .. 3) { send_key "ret"; }

    #Restart firefox
    send_key "ctrl-q";
    x11_start_program("firefox");
    $self->firefox_check_popups;
    assert_screen('firefox-gnome', 60);

    send_key "esc";
    send_key "alt-d";
    type_string $mozlogin. "\n";
    $self->firefox_check_popups;

    assert_and_click('firefox-passwd-input_username');
    type_string "squiddy";
    send_key "tab";
    type_string "calamari";
    send_key "ret";
    assert_and_click('firefox-passwd-confirm_remember');
    assert_screen('firefox-passwd-confirm_master_pw', 30);
    type_string $masterpw. "\n";

    send_key "esc";
    send_key "alt-d";
    type_string $mozlogin. "\n";
    $self->firefox_check_popups;
    assert_screen('firefox-passwd-auto_filled', 90);

    send_key "alt-e";
    send_key "n";    #Preferences
    assert_and_click('firefox-passwd-security');
    send_key "alt-shift-p";    #"Saved Passwords..."
    send_key "alt-shift-p";    #"Show Passwords"
    type_string $masterpw. "\n";
    send_key "alt-shift-l";
    assert_screen('firefox-passwd-saved', 30);

    send_key "alt-shift-a";    #"Remove"
    wait_still_screen 3;
    send_key "alt-y";
    send_key "alt-shift-c";
    send_key "ctrl-w";
    send_key "f5";
    assert_screen('firefox-passwd-removed', 60);

    # Exit
    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
