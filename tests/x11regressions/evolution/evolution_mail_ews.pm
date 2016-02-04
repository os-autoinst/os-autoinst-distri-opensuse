#Test Case #1503965: Evolution: Setup MS Exchange account

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
    if (check_screen "evolution-default-client-ask", 30) {
        assert_and_click "evolution-default-client-agree";
    }

    # Follow the wizard to setup mail account 
    assert_screen "test-evolution-1", 30;
    send_key "alt-o";
    assert_screen "evolution_wizard-restore-backup", 30;
    send_key "alt-o";
    assert_screen "evolution_wizard-identity", 30;
    send_key "alt-e";
    type_string "SUSE Test";
    send_key "alt-a";
    type_string "$mailbox";
    sleep 1;
    save_screenshot();

    send_key "alt-o";
    if (check_screen "evolution_wizard-skip-lookup", 30) {
        send_key "alt-s";
    }
    assert_screen"evolution_wizard-receiving", 30;

    send_key "alt-t", 1;
    send_key "ret", 1;
    send_key_until_needlematch "evolution_wizard-receiving-ews", "up", 10, 3;
    send_key "ret";
    assert_screen "evolution_wizard-ews-prefill", 30; 
    send_key "alt-u";
    assert_screen "evolution_mail-auth", 30;
    type_string "$mail_passwd";
    send_key "ret";
    assert_screen "evolution_wizard-ews-oba", 30; 
    send_key "alt-o";
    assert_screen "evolution_wizard-receiving-opts", 30;
    assert_and_click "evolution_wizard-ews-enable-gal";
    assert_and_click "evolution_wizard-ews-fetch-abl";
    assert_screen "evolution_wizard-ews-view-gal", 120;
    send_key "alt-o";
    assert_screen "evolution_wizard-account-summary", 30;
    send_key "alt-o";
    assert_screen "evolution_wizard-done", 30;
    send_key "alt-a";
    assert_screen "evolution_mail-auth", 30;
    type_string "$mail_passwd";
    send_key "ret";
    if (check_screen "evolution_mail-init-window", 30) {
        send_key "super-up";
    }
    assert_screen "evolution_mail-max-window", 30;

    # Make all existing mails as read
    assert_screen "evolution_mail-online", 60;
    assert_and_click "evolution_mail-inbox";
    sleep 1;
    assert_screen "evolution_mail-ready", 60;
    send_key "ctrl-/";
    if (check_screen "evolution_mail-confirm-read", 30) {
        send_key "alt-y";
    }
    assert_screen "evolution_mail-ready", 60;

    # Send and receive new email
    send_key "shift-ctrl-m";
    assert_screen "evolution_mail-compose-message", 30;
    assert_and_click "evolution_mail-message-to";
    type_string "$mailbox";
    send_key "alt-u";
    type_string "Testing";
    assert_and_click "evolution_mail-message-body";
    type_string "Test email send and receive.";
    send_key "ctrl-ret";
    if (check_screen "evolution_mail-auth", 30) {
        type_string "$mail_passwd";
        send_key "ret";
    }

    send_key_until_needlematch "evolution_mail-notification", "f12", 10, 10;
    send_key "alt-w", 1;
    send_key "ret", 1;
    send_key_until_needlematch "evolution_mail-show-unread", "down", 15, 3;
    send_key "ret";

    assert_and_click "evolution_mail-view-message";
    assert_screen "evolution_mail-ready", 30;
    assert_screen "evolution_mail-message-info", 30;
    send_key "ctrl-d"; #Delete the message and expunge the deleted item
    save_screenshot();
    send_key "ctrl-e";
    if (check_screen "evolution_mail-expunge", 30) {
        send_key "alt-e";
    }
    sleep 1;
    assert_screen "evolution_mail-ready", 30;
    
    # Exit
    send_key "ctrl-q";
}
1;
# vim: set sw=4 et:
