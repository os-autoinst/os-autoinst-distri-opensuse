# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test Case #1503965: Evolution: Setup MS Exchange account
# Maintainer: Qingming Su <qingming.su@suse.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {

    my ($self)      = @_;
    my $mailbox     = 'zzzSUSEExTest19@microfocus.com';
    my $mail_passwd = 'P@$$w0rd2015';

    $self->setup_evolution_for_ews($mailbox, $mail_passwd);

    # Send and receive new email
    send_key "shift-ctrl-m";
    assert_screen "evolution_mail-compose-message";
    assert_and_click "evolution_mail-message-to";
    type_string "$mailbox";
    assert_screen_change {
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
    assert_screen_change {
        send_key "alt-w";
    };
    send_key "ret";
    send_key_until_needlematch "evolution_mail-show-unread", "down", 15, 3;
    send_key "ret";

    assert_and_click "evolution_mail-view-message";
    assert_screen "evolution_mail-ready";
    assert_screen "evolution_mail-message-info";
    # Delete the message and expunge the deleted item
    assert_screen_change {
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
