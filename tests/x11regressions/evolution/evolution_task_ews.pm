# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Test Case #1503757: Evolution:Send MS task

use strict;
use base "x11test";
use testapi;

sub run() {
    my $mailbox     = 'zzzSUSEExTest19@microfocus.com';
    my $mail_passwd = 'P@$$w0rd2015';

    mouse_hide(1);

    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs rm -rf;\"");
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
    if (check_screen "evolution_wizard-skip-lookup") {
        send_key "alt-s";
    }
    assert_screen "evolution_wizard-receiving";

    wait_screen_change {
        send_key "alt-t";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-ews", "up", 10, 3;
    send_key "ret";
    assert_screen "evolution_wizard-ews-prefill";
    send_key "alt-u";
    assert_screen "evolution_mail-auth";
    type_string "$mail_passwd";
    send_key "ret";
    assert_screen "evolution_wizard-ews-oba";
    send_key "alt-o";
    assert_screen "evolution_wizard-receiving-opts";
    assert_and_click "evolution_wizard-ews-enable-gal";
    assert_and_click "evolution_wizard-ews-fetch-abl";
    assert_screen [qw/evolution_wizard-ews-view-gal evolution_mail-auth/], 120;
    if (match_has_tag('evolution_mail-auth')) {
        type_string "$mail_passwd";
        send_key "ret";
        assert_screen "evolution_wizard-ews-view-gal", 120;
    }
    send_key "alt-o";
    assert_screen "evolution_wizard-account-summary";
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

    # Make all existing mails as read
    assert_screen "evolution_mail-online", 60;
    assert_and_click "evolution_mail-inbox";
    assert_screen "evolution_mail-ready", 60;
    send_key "ctrl-/";
    if (check_screen "evolution_mail-confirm-read") {
        send_key "alt-y";
    }
    assert_screen "evolution_mail-ready", 60;

    # Send and receive new task
    send_key "shift-ctrl-t";
    assert_screen "evolution_task-compose-task";
    send_key "alt-m";
    type_string "test for task";
    assert_and_click "task-save";
    send_key "alt-f4";
    wait_still_screen;
    assert_and_click "switch-to-task";
    wait_still_screen;
    assert_and_click "added-test-task";
    wait_still_screen;
    send_key "ctrl-f";
    wait_still_screen;
    type_string "$mailbox";
    save_screenshot();
    send_key "ctrl-ret";

    if (check_screen "evolution_mail-auth") {
        type_string "$mail_passwd";
        send_key "ret";
    }

    assert_and_click "switch-to-mail";
    send_key_until_needlematch "evolution_mail-notification", "f12", 10, 10;
    send_key "alt-w";
    wait_still_screen;

    send_key "ret";
    send_key_until_needlematch "evolution_mail-show-unread", "down", 15, 3;
    send_key "ret";

    assert_screen "evolution_task-received-task-info";

    # Delete the message and expunge the deleted item
    send_key "ctrl-d";
    wait_still_screen;
    save_screenshot();

    send_key "ctrl-e";
    if (check_screen "evolution_mail-expunge") {
        send_key "alt-e";
    }
    assert_screen "evolution_mail-ready";

    # Exit
    send_key "ctrl-q";
    wait_idle;
}

1;
# vim: set sw=4 et:
