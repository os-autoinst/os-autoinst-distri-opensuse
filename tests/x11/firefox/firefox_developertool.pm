# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479522: Firefox: Web Developer Tools
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {

    my ($self) = @_;
    $self->start_firefox_with_profile;

    $self->firefox_open_url('opensuse.org');
    assert_screen('firefox-developertool-opensuse');
    send_key 'f12';
    assert_screen('firefox-developertool-gerneral', 30);
    assert_and_click "firefox-developertool-click_element";
    assert_screen "firefox-developertool-check_inspector";
    assert_and_click "firefox-developertool-check_element";
    assert_screen("firefox-developertool-element", 30);
    assert_and_click "firefox-developertool-console_button";
    send_key "f5";
    assert_screen("firefox-developertool-console_contents", 30);

    $self->exit_firefox;
}
1;
