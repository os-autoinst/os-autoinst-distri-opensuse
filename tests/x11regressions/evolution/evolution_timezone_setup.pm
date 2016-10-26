# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#testcase 5255-1503908:Evolution: setup timezone

# Summary: tc#1503908: evolution_timezone_setup
# Maintainer: Chingkai <qkzhu@suse.com>

use strict;
use base "x11regressiontest";
use testapi;
use utils;

sub run() {
    my $mailbox     = 'nooops_test3@aim.com';
    my $mail_passwd = 'opensuse';
    my $next_key    = 'alt-o';

    if (sle_version_at_least('12-SP2')) {
        $next_key = "alt-n";
    }

    mouse_hide(1);

    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"");
    x11_start_program("evolution");
    assert_screen [qw(evolution-default-client-ask test-evolution-1)];
    if (match_has_tag "evolution-default-client-ask") {
        assert_and_click "evolution-default-client-agree";
        assert_screen 'test-evolution-1';
    }

    # Follow the wizard to complete the first launch steps
    send_key $next_key;
    assert_screen "evolution_wizard-restore-backup";
    send_key $next_key;
    assert_screen "evolution_wizard-identity";
    send_key "alt-e";
    type_string "SUSE Test";
    send_key "alt-a";
    wait_still_screen;
    type_string "$mailbox";
    sleep 1;
    save_screenshot();

    send_key $next_key;
    assert_screen [qw(evolution_wizard-skip-lookup evolution_wizard-receiving)];
    if (match_has_tag "evolution_wizard-skip-lookup") {
        send_key "alt-s";
        assert_screen 'evolution_wizard-receiving';
    }

    send_key "alt-t";
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-none", "up";
    send_key "ret";
    wait_still_screen;

    send_key $next_key;
    wait_still_screen;
    assert_screen "evolution_wizard-sending";
    send_key "alt-t";
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-sending-sendmail", "down";
    send_key "ret";
    wait_still_screen;
    send_key $next_key;
    wait_still_screen;

    assert_screen "evolution_wizard-account-summary";
    if (sle_version_at_least('12-SP2')) {
        assert_and_click "evolution-option-next";
    }
    else {
        send_key $next_key;
    }
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    if (check_screen "evolution_mail-init-window") {
        send_key "super-up";
    }
    assert_screen "evolution_mail-max-window";

    # Set up timezone via: Edit->Preference->calendor and task->uncheck "use
    # sYstem timezone", then select
    send_key "alt-e";
    send_key_until_needlematch "evolution-preference-highlight", "down";
    send_key "ret";
    assert_screen "evolution-preference";
    send_key_until_needlematch "evolution-calendorAtask", "down";
    send_key "alt-y";
    assert_and_click "timezone-select";
    assert_screen "evolution-selectA-timezone";
    assert_and_click "mercator-projection";
    assert_screen "mercator-zoomed-in";
    if (sle_version_at_least('12-SP2')) {
        send_key "alt-s";
        wait_still_screen 3;
        send_key "ret";
    }
    else {
        assert_and_click "time-zone-selection";
    }
    send_key_until_needlematch("timezone-asia-shanghai", "up") || send_key_until_needlematch("timezone-asia-shanghai", "down");
    send_key "ret";
    assert_screen "asia-shanghai-timezone-setup";
    send_key "alt-o";
    wait_still_screen;
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:

