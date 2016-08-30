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
use base "x11regressiontest";
use testapi;
use utils;

sub run() {
    my $self         = shift;
    my $account      = "internal_account_A";
    my $config       = $self->getconfig_emailaccount;
    my $mailbox      = $config->{$account}->{mailbox};
    my $mail_passwd  = $config->{$account}->{passwd};
    my $mail_subject = $self->get_dated_random_string(4);
    $self->setup_pop("internal_account_A");

    # Send and receive new email
    send_key "shift-ctrl-m";
    assert_screen "evolution_mail-compose-message";
    assert_and_click "evolution_mail-message-to";
    type_string "$mailbox";
    send_key "alt-u";
    wait_still_screen;
    type_string "$mail_subject this is a pop test mail";
    assert_and_click "evolution_mail-message-body";
    type_string "Test email send and receive.";
    send_key "ctrl-ret";
    if (sle_version_at_least('12-SP2')) {
        if (check_screen "evolution_mail_send_mail_dialog") {
            send_key "ret";
        }
    }
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-a";    #disable keyring option, only in SP2
            send_key "alt-p";
        }
        type_string "$mail_passwd";
        send_key "ret";
    }
    $self->check_new_mail_evolution($mail_subject, $account, "pop");

    # Exit
    send_key "ctrl-q";
}

1;
# vim: set sw=4 et:
