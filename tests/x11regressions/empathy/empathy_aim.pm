# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# Case 1503972 - Empathy: AIM

sub run() {
    my $self      = shift;
    my $USERNAME0 = "nooops_test3";
    my $USERNAME1 = "nooops_test4";
    my $DOMAIN    = "aim";
    my $PASSWD    = "opensuse";

    #x11_start_program ("xterm -e killall -9 empathy");
    x11_start_program("empathy");

    assert_screen('empathy-accounts-discover', 10);
    send_key "alt-s";    # skip accounts discover

    # add one aim account- aim1

    # choose aim account type
    assert_and_click 'empathy-add-account';
    assert_and_click 'empathy-account-type';
    send_key_until_needlematch 'empathy-account-aim', 'down';
    send_key "ret";

    type_string $USERNAME0. "@" . $DOMAIN . ".com";
    send_key "tab";
    type_string $PASSWD;
    send_key "alt-d";

    # check status
    assert_screen('empathy-aim-aim1-success', 30);

    # add another aim account- aim2

    # choose aim account type
    assert_and_click 'empathy-add-account';
    assert_and_click 'empathy-account-type';
    send_key_until_needlematch 'empathy-account-aim', 'down';
    send_key "ret";

    type_string $USERNAME1. "@" . $DOMAIN . ".com";
    send_key "tab";
    type_string $PASSWD;
    send_key "alt-d";

    # check status
    assert_screen('empathy-aim-aim2-success', 30);
    send_key "alt-c";
    assert_screen('empathy-aim-available-status', 10);

    # select the test4 account to talk
    assert_and_click 'empathy-aim-contact-list';
    send_key_until_needlematch 'empathy-contact-test4', 'down';
    send_key "ret";

    # send a message and then close the dialog
    assert_screen('empathy-dialog-window', 20);
    type_string "test from openqa";
    send_key "ret";
    assert_screen('empathy-aim-sent-message', 5);
    send_key "ctrl-w";
    assert_screen('empathy-close-dialog', 5);

    # cleaning
    send_key "f4";
    assert_and_click 'empathy-disable-aim-account0';
    assert_and_click 'empathy-delete-aim-account0';
    assert_screen('empathy-confirm-aim-deletion0', 5);
    send_key "alt-r", 1;

    assert_and_click 'empathy-disable-aim-account1';
    assert_and_click 'empathy-delete-aim-account1';
    assert_screen('empathy-confirm-aim-deletion1', 5);
    send_key "alt-r", 1;

    send_key "alt-c", 1;

    # quit
    send_key "ctrl-q";
}
1;
# vim: set sw=4 et:
