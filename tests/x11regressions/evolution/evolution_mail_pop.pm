# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Test Case #1503919 - Evolution: send and receive email via POP

use strict;
use base "x11test";
use testapi;

sub run() {
    my $mailbox       = 'zzzSUSEExTest19@gmail.com';
    my $recv_server   = 'pop.gmail.com';
    my $smtp_server   = 'smtp.gmail.com';
    my $mail_user     = 'zzzSUSEExTest19';
    my $mail_passwd   = 'P@$$w0rd2015';
    my $mail_recvport = '995';
    my $mail_sendport = '587';

    mouse_hide(1);

    # Clean and Start Evolution
    x11_start_program("xterm");
    type_string "killall -9 evolution\n";
    assert_script_run "find /home/$username -name evolution | xargs rm -rf";
    send_key 'alt-f4';
    x11_start_program("evolution");

    # Follow the wizard to setup mail account
    assert_screen "test-evolution-1";
    send_key "alt-o";
    assert_screen "evolution_wizard-restore-backup";
    send_key "alt-o";
    assert_screen "evolution_wizard-identity";
    send_key "alt-e";
    wait_still_screen;
    type_string "SUSE Test";
    send_key "alt-a";
    wait_still_screen;
    type_string "$mailbox";
    sleep 1;
    save_screenshot();

    send_key "alt-o";
    if (check_screen "evolution_wizard-skip-lookup") {
        send_key "alt-s";
    }

    assert_screen "evolution_wizard-receiving";
    send_key "alt-t";
    wait_still_screen;
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-pop", "down";
    send_key "ret";
    wait_still_screen;

    send_key "alt-s";
    wait_still_screen;
    type_string "$recv_server";
    send_key "alt-p";
    wait_still_screen;
    type_string "$mail_recvport";
    send_key "alt-n";
    wait_still_screen;
    type_string "$mail_user";
    send_key "alt-m";
    wait_still_screen;
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-ssl", "down";
    send_key "ret";
    wait_still_screen;
    send_key "alt-o";
    assert_screen "evolution_wizard-receiving-opts";

    send_key "alt-o";
    assert_screen "evolution_wizard-sending";
    send_key "alt-t";
    wait_still_screen;
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-sending-smtp", "down";
    send_key "ret";
    wait_still_screen;
    send_key "alt-s";
    wait_still_screen;
    type_string "$smtp_server";
    send_key "alt-p";
    wait_still_screen;
    type_string "$mail_sendport";
    send_key "alt-v";
    wait_still_screen;
    send_key "alt-m";
    wait_still_screen;
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-sending-starttls", "down";
    send_key "ret";

    assert_and_click "evolution_wizard-sending-authcheck";
    assert_screen "evolution_wizard-sending-authtype-pop", 120;
    send_key "alt-n";
    wait_still_screen;
    type_string "$mail_user";
    sleep 1;
    save_screenshot();

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
    assert_screen "evolution_mail-online", 120;
    assert_and_click "evolution_mail-inbox-pop";
    # ?????? Why mail ready ??????
    assert_screen "evolution_mail-ready", 60;
    send_key "ctrl-/";
    if (check_screen "evolution_mail-confirm-read") {
        send_key "alt-y";
    }
    # ?????? Why mail ready ??????
    assert_screen "evolution_mail-ready", 60;

    # Send and receive new email
    send_key "shift-ctrl-m";
    assert_screen "evolution_mail-compose-message";
    assert_and_click "evolution_mail-message-to";
    type_string "$mailbox";
    send_key "alt-u";
    wait_still_screen;
    type_string "Testing";
    assert_and_click "evolution_mail-message-body";
    type_string "Test email send and receive.";
    send_key "ctrl-ret";
    if (check_screen "evolution_mail-auth") {
        type_string "$mail_passwd";
        send_key "ret";
    }

    send_key_until_needlematch "evolution_mail-notification", "f12", 10, 10;
    send_key "alt-w";
    wait_still_screen;
    send_key "ret";
    send_key_until_needlematch "evolution_mail-show-unread", "down";
    send_key "ret";

    assert_and_click "evolution_mail-view-message";
    assert_screen "evolution_mail-ready", 60;
    assert_screen "evolution_mail-message-info";

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
}

1;
# vim: set sw=4 et:
