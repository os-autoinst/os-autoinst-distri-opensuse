# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: add empathy irc regression test
# G-Maintainer: mitiao <mitiao@gmail.com>

use base "x11regressiontest";
use strict;
use testapi;
use utils;

# Case 1478813 - Empathy: IRC

sub run() {
    my $self = shift;
    x11_start_program("empathy");

    assert_screen 'empathy-accounts-discover';
    send_key "alt-s";    # skip accounts discover

    # choose irc account type
    assert_and_click 'empathy-add-account';
    assert_and_click 'empathy-account-type';
    send_key_until_needlematch 'empathy-account-irc', 'down';
    send_key "ret";

    # select freenode irc network
    assert_and_click 'empathy-irc-network';
    type_string "freenode";
    assert_screen 'empathy-irc-freenode';
    wait_screen_change {
        send_key "ret";
    };
    send_key "tab";
    # add a random irc account
    my $rstr = $self->random_string(4);
    type_string "openqa-$rstr";
    send_key "alt-d";
    assert_screen 'empathy-irc-account-added';
    wait_screen_change {
        send_key "alt-c";
    };

    # join openqa channel
    if (sle_version_at_least('12-SP2')) {
        assert_and_click 'empathy-menu';
        send_key_until_needlematch "empathy-menu-rooms", "down";
        assert_and_click 'empathy-menu-joinrooms';
        record_soft_failure 'bsc#999832: keyboard shortcut of empathy not working on SLED12SP2';
    }
    else {
        send_key "ctrl-j";
    }
    assert_screen 'empathy-join-room';
    type_string "openqa";
    send_key "ret";

    # send a message and then leave the channel
    assert_screen 'empathy-room-window';
    type_string "This test message was sent by openQA\n";
    assert_screen 'empathy-sent-message';
    send_key "ctrl-w";
    assert_screen 'empathy-leave-room';
    send_key "ret";

    # cleaning
    if (sle_version_at_least('12-SP2')) {
        assert_and_click 'empathy-menu';
        assert_and_click 'empathy-menu-accounts';
    }
    else {
        send_key "f4";
    }
    assert_and_click 'empathy-disable-account';
    assert_and_click 'empathy-delete-account';
    assert_screen 'empathy-confirm-deletion';
    send_key "alt-r";
    assert_screen 'empathy-account-deleted';
    wait_screen_change {
        send_key "alt-c";
    };

    # quit
    if (sle_version_at_least('12-SP2')) {
        assert_and_click 'empathy-menu';
        assert_and_click 'empathy-menu-quit';
    }
    else {
        send_key "ctrl-q";
    }
}

1;
# vim: set sw=4 et:
