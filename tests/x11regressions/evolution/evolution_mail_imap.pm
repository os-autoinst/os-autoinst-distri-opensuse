# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Test Case #1503768: Evolution: send and receive email via IMAP

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    my $mailbox       = 'zzzSUSEExTest19@microfocus.com';
    my $mail_server   = 'mail.microfocus.com';
    my $mail_user     = 'zzzSUSEExTest19';
    my $mail_passwd   = 'P@$$w0rd2015';
    my $mail_recvport = '993';
    my $mail_sendport = '587';

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
    send_key_until_needlematch "evolution_wizard-receiving-imap", "down", 10, 3;
    wait_screen_change {
        send_key "ret";
    };

    wait_screen_change {
        send_key "alt-s";
    };
    type_string "$mail_server";
    wait_screen_change {
        send_key "alt-p";
    };
    type_string "$mail_recvport";
    wait_screen_change {
        send_key "alt-n";
    };
    type_string "$mail_user";
    wait_screen_change {
        send_key "alt-m";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-receiving-ssl", "down", 5, 3;
    wait_screen_change {
        send_key "ret";
    };
    send_key "alt-o";
    assert_screen "evolution_wizard-receiving-opts";

    send_key "alt-o";
    assert_screen "evolution_wizard-sending";
    wait_screen_change {
        send_key "alt-t";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-sending-smtp", "down", 5, 3;
    wait_screen_change {
        send_key "ret";
    };
    wait_screen_change {
        send_key "alt-s";
    };
    type_string "$mail_server";
    wait_screen_change {
        send_key "alt-p";
    };
    type_string "$mail_sendport";
    wait_screen_change {
        send_key "alt-v";
    };
    wait_screen_change {
        send_key "alt-m";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_wizard-sending-starttls", "down", 5, 3;
    send_key "ret";

    #Known issue: hot key 'alt-y' doesn't work
    #wait_screen_change {
    #   send_key "alt-y";
    #};
    #send_key "ret";
    #send_key_until_needlematch "evolution_wizard-sending-authtype", "down", 5, 3;
    #send_key "ret";
    #Workaround of above issue: click the 'Check' button
    assert_and_click "evolution_wizard-sending-authcheck";
    assert_screen "evolution_wizard-sending-authtype", 120;
    wait_screen_change {
        send_key "alt-n";
    };
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
    assert_and_click "evolution_mail-inbox";
    assert_screen "evolution_mail-ready", 60;
    send_key "ctrl-/";
    if (check_screen "evolution_mail-confirm-read") {
        send_key "alt-y";
    }
    assert_screen "evolution_mail-ready", 60;

    # Send and receive new email
    send_key "shift-ctrl-m";
    assert_screen "evolution_mail-compose-message";
    assert_and_click "evolution_mail-message-to";
    type_string "$mailbox";
    wait_screen_change {
        send_key "alt-u";
    };
    type_string "Testing";
    assert_and_click "evolution_mail-message-body";
    type_string "Test email send and receive.";
    send_key "ctrl-ret";
    if (check_screen "evolution_mail-auth") {
        type_string "$mail_passwd";
        send_key "ret";
    }

    send_key_until_needlematch "evolution_mail-notification", "f12", 10, 10;
    wait_screen_change {
        send_key "alt-w";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_mail-show-unread", "down", 15, 3;
    send_key "ret";

    assert_and_click "evolution_mail-view-message";
    assert_screen "evolution_mail-ready", 60;
    assert_screen "evolution_mail-message-info";
    # Delete the message and expunge the deleted item
    wait_screen_change {
        send_key "ctrl-d";
    };
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
