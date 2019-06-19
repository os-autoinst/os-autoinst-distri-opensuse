# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Firefox Case#1479190: Add-ons - Appearance
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    send_key "ctrl-shift-a";
    assert_and_click('firefox-appearance-tabicon');
    assert_screen('firefox-appearance-default', 30);

    $self->firefox_open_url('addons.mozilla.org/en-US/firefox/addon/opensuse');
    assert_screen('firefox-appearance-mozilla_addons');
    for (1 .. 3) {
        assert_and_click 'firefox-appearance-addto';
        if (check_screen("firefox-appearance-addto-permissions_requested", 10)) {
            assert_and_click "firefox-appearance-addto-permissions_requested";
        }
        last if check_screen 'firefox-appearance-installed', 90;
    }

    $self->exit_firefox;
}
1;
