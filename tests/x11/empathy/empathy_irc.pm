# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Empathy irc regression test
# Maintainer: Chingkai <qkzhu@suse.com>
# Tags: tc#1478813

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;


sub run {
    x11_start_program('empathy', target_match => 'empathy-accounts-discover');
    send_key "alt-s";    # skip accounts discover

    # choose irc account type
    assert_and_click 'empathy-add-account';
    assert_and_click 'empathy-account-type';
    send_key_until_needlematch 'empathy-account-irc', 'down';
    send_key "ret";

    # select freenode irc network
    assert_and_click 'empathy-irc-network';
    assert_screen 'empathy-irc-network-choose';
    type_string "freenode";
    assert_screen 'empathy-irc-freenode';
    wait_screen_change {
        send_key "ret";
    };
    send_key "tab";
    # add a random irc account
    my $rstr = random_string(4);
    type_string "openqa-$rstr";
    send_key "alt-d";
    assert_screen 'empathy-irc-account-added';
    send_key 'alt-c';
    wait_still_screen 3;

    # join openqa channel
    send_key "ctrl-j";
    assert_screen "empathy-join-room";
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
    send_key "f4";
    if (!check_screen 'empathy-disable-account', 30) {
        assert_and_click 'empathy-menu';
        assert_and_click 'empathy-menu-accounts';
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
    send_key "ctrl-q";
    wait_still_screen 3;
    if (check_screen 'empathy-menu', 0) {
        assert_and_click 'empathy-menu';
        assert_and_click 'empathy-menu-quit';
    }
}

1;
