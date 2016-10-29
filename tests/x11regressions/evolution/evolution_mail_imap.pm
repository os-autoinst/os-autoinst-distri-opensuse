# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Test Case #1503768: Evolution: send and receive email via IMAP

# G-Summary: Add three test cases for Evolution
#    evolution_smoke: Case #1503857: Evolution setup assistant
#    evolution_mail_imap: Case #1503768: send and receive email via IMAP
#    evolution_mail_ews: Case #1503965: Setup MS Exchange account
# G-Maintainer: Qingming Su <qingming.su@suse.com>

use strict;
#use base "x11test";
use base "x11regressiontest";
use testapi;
use utils;

sub run() {
    my $self = shift;

    $self->setup_mail_account('imap', "internal_account_A");

    my $mail_subject = $self->get_dated_random_string(4);

    send_key "shift-ctrl-m";
    assert_screen "evolution_mail-compose-message";
    assert_and_click "evolution_mail-message-to";
    type_string "$mail_box";
    wait_screen_change {
        send_key "alt-u";
    };
    type_string "$mail_subject this is a imap test mail";
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

    $self->check_new_mail_evolution($mail_subject, $account, "imap");

    # Exit
    send_key "ctrl-q";
    wait_idle;
}

1;
# vim: set sw=4 et:
