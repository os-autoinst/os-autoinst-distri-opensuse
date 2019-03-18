# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test firefox HTTP headers (Case#1436066)
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    # open network monitor tab in developer tools
    send_key 'ctrl-shift-e';
    assert_screen 'firefox-headers-inspector';
    $self->firefox_open_url('gnu.org');
    assert_screen('firefox-headers-website');

    assert_and_click('firefox-headers-select-html');
    # to see new request window after edit and resend on SLE15
    assert_and_click('firefox-headers-select-other');
    # refresh page
    send_key 'f5';
    wait_still_screen 3;
    assert_screen 'firefox-url-loaded';
    assert_and_click('firefox-headers-select-gnu.org');
    assert_screen('firefox-headers-first_item');

    send_key "shift-f10";
    #"Edit and Resend"
    send_key "e";

    assert_screen('firefox-headers-user_agent', 50);

    # Exit
    $self->exit_firefox;
}
1;
