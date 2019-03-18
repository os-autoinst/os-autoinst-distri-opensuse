# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436079: Firefox: Password Management
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;

    my $masterpw = "firefox_test";
    my $mozlogin = "https://www-archive.mozilla.org/quality/browser/front-end/testcases/wallet/login.html";

    # Start Firefox
    $self->start_firefox_with_profile;

    send_key "alt-e";
    wait_still_screen 3;
    send_key "n";
    assert_and_click('firefox-passwd-security');

    send_key "alt-shift-u";
    wait_still_screen 3;
    send_key 'spc';

    assert_screen('firefox-passwd-master_setting');

    type_string $masterpw;
    send_key "tab";
    type_string $masterpw;

    # confirm password change
    for (1 .. 2) { send_key 'tab'; }
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
    assert_and_click('firefox-passwd-confirm_remember');
    assert_screen('firefox-passwd-confirm_master_pw');
    type_string $masterpw. "\n";

    $self->firefox_open_url($mozlogin);
    assert_screen('firefox-passwd-auto_filled');

    send_key "alt-e";
    send_key "n";    #Preferences
    assert_and_click('firefox-passwd-security');
    send_key "alt-shift-p";    #"Saved Passwords..."
    send_key "alt-shift-p";    #"Show Passwords"
    type_string $masterpw. "\n";
    send_key "alt-shift-l";
    wait_still_screen 3;
    send_key 'spc';
    assert_screen('firefox-passwd-saved');

    send_key "alt-shift-a";    #"Remove"
    wait_still_screen 3;
    send_key "alt-y";
    wait_still_screen 3;
    send_key "alt-shift-c";
    wait_still_screen 3;
    send_key "ctrl-w";
    wait_still_screen 3;
    send_key "f5";
    assert_screen('firefox-passwd-removed', 60);

    # Exit
    $self->exit_firefox;
}
1;
