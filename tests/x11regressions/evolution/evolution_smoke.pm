# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Test Case #1503857 - Evolution: First time launch and setup assistant

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    my $mailbox     = 'nooops_test3@aim.com';
    my $mail_passwd = 'opensuse';

    mouse_hide(1);

    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs -rm -rf;\"");
    x11_start_program("evolution");
    if (check_screen "evolution-default-client-ask") {
        assert_and_click "evolution-default-client-agree";
    }

    # Follow the wizard to setup mail account
    assert_screen "test-evolution-1";
    send_key "alt-o";
    assert_screen "evolution_wizard-restore-backup";
    send_key "alt-o";
    assert_screen "evolution_wizard-identity";
    wait_screen_change {
        send_key "alt-e";
    };
    type_string "SUSE Test";
    wait_screen_change {
        send_key "alt-a";
    };
    type_string "$mailbox";
    sleep 1;
    save_screenshot();

    send_key "alt-o";
    assert_screen "evolution_wizard-account-summary", 60;
    send_key "alt-o";
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    assert_screen "evolution_mail-auth";
    type_string "$mail_passwd";
    send_key "ret";
    if (check_screen "evolution_mail-init-window") {
        send_key "super-up";
    }
    assert_screen "evolution_mail-max-window";

    # Help
    wait_screen_change {
        send_key "alt-h";
    };
    send_key "a";
    assert_screen "evolution_about";
    wait_screen_change {
        send_key "esc";
    };

    # Exit
    send_key "ctrl-q";
    wait_idle;
}

1;
# vim: set sw=4 et:
