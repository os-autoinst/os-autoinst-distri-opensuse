# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479189: Firefox: Add-ons - Extensions
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    my ($self) = @_;
    $self->start_firefox;

    assert_screen('firefox-extensions-no_flag', 90);
    send_key "ctrl-w";
    wait_still_screen 3;
    send_key "ctrl-shift-a";
    assert_screen('firefox-addons_manager', 90);

    assert_and_click "firefox-searchall-addon";
    type_string "flagfox\n";
    assert_and_click('firefox-extensions-flagfox', 'right');
    assert_and_click('firefox-extensions-flagfox_install');
    assert_screen('firefox-extensions-flagfox_installed', 90);

    send_key "alt-1";
    assert_screen('firefox-extensions-show_flag', 60);

    sleep 1;
    send_key "alt-3";
    assert_and_click('firefox-extensions-flagfox_installed');

    sleep 2;
    send_key "alt-1";
    assert_screen('firefox-extensions-no_flag', 90);

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
