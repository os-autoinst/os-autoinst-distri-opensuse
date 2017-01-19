# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Firefox emaillink test (Case#1436117)
# Maintainer: wnereiz <wnereiz@github>

use strict;
use base "x11regressiontest";
use testapi;
use utils;

sub run() {
    my ($self) = @_;
    my $next_key = "alt-o";

    if (sle_version_at_least('12-SP2')) {
        $next_key = "alt-n";
    }

    $self->start_firefox;

    # Email link
    send_key "alt-f";
    wait_still_screen 3;
    send_key "e";
    assert_screen('firefox-email_link-welcome', 90);

    send_key $next_key;

    wait_still_screen 3;
    send_key $next_key;

    wait_still_screen 3;
    send_key "alt-a";
    type_string 'test@suse.com';
    send_key $next_key;

    sleep 1;
    send_key "alt-s";    #Skip

    assert_screen('firefox-email_link-settings_receiving', 90);
    send_key "alt-s";    #Server
    type_string "imap.suse.com";
    send_key "alt-n";    #Username
    type_string "test";
    if (sle_version_at_least('12-SP2')) {
        assert_and_click "evolution-option-next";
        wait_still_screen 3;
        assert_and_click "evolution-option-next";
    }
    else {
        send_key $next_key;
        wait_still_screen 3;
        send_key $next_key;
    }

    assert_screen('firefox-email_link-settings_sending');
    send_key "alt-s";    #Server
    type_string "smtp.suse.com";
    assert_screen_change {
        send_key $next_key;
    };

    wait_still_screen 3;
    if (sle_version_at_least('12-SP2')) {
        assert_and_click "evolution-option-next";
    }
    else {
        send_key $next_key;
    }

    wait_still_screen 3;
    send_key "alt-a";

    assert_screen('firefox-email_link-send');
    assert_screen_change {
        send_key "esc";
    };

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
