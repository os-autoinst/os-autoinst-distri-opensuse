# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test firefox HTTP headers (Case#1436066)
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11test";
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    # open network monitor tab in developer tools
    my $key = is_sle('15+') ? 'e' : 'q';
    send_key "ctrl-shift-$key";
    assert_screen 'firefox-headers-inspector';
    $self->firefox_open_url('www.gnu.org');
    assert_screen('firefox-headers-website', 90);

    if (is_sle('15+')) {
        assert_and_click('firefox-headers-select-gnu.org');
    }
    else {
        send_key "down";
    }
    assert_screen('firefox-headers-first_item', 50);

    send_key "shift-f10";
    #"Edit and Resend"
    send_key "e";

    assert_screen('firefox-headers-user_agent', 50);

    # Exit
    $self->exit_firefox;
}
1;
