use strict;
use base "x11test";
use testapi;

sub run() {
    my $mailbox     = 'nooops_test3@aim.com';
    my $mail_passwd = 'opensuse';

    mouse_hide(1);

    # Clean and Start Evolution
    x11_start_program("xterm -e \"killall -9 evolution; find ~ -name evolution | xargs -rm -rf;\"");
    x11_start_program("evolution");
    if (check_screen "evolution-default-client-ask", 30) {
        assert_and_click "evolution-default-client-agree", 30;
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
    assert_screen "evolution_wizard-account-summary", 60;
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

    # Help
    send_key "alt-h", 1;
    send_key "a";
    assert_screen "evolution_about", 5;
    send_key "esc";

    # Exit
    send_key "ctrl-q";
    wait_idle;
}
1;
# vim: set sw=4 et:
