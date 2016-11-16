# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test Case #1503757: Evolution:Send MS task
# Maintainer: xiaojun <xjin@suse.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {

    my ($self)      = @_;
    my $mailbox     = 'zzzSUSEExTest19@microfocus.com';
    my $mail_passwd = 'P@$$w0rd2015';

    $self->setup_evolution_for_ews($mailbox, $mail_passwd);

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
