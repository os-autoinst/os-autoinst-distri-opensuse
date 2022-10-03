# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: hexchat
# Summary: FIPS : hexchat_ssl
# Maintainer: QE Security <none@suse.de>
# Tags: poo#49139 , poo#49136 , poo#52796

use base "x11test";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub irc_login_send_message {
    my ($name) = @_;

    my @tags = ("$name-connection-complete-dialog", "$name-SASL-only-error");
    assert_screen \@tags;
    if (match_has_tag("$name-connection-complete-dialog")) {
        wait_still_screen;
        # start to change the channel name
        assert_and_click "$name-join-channel";
        assert_screen "$name-join-channel-select";
        # clear original '#hexchat' channel name
        wait_still_screen 2;
        send_key "ctrl-a";
        send_key "delete";
        wait_still_screen 2;

        # change name to '#openqa-test_irc_from_openqa' and join this channel
        enter_cmd "#openqa-test_irc_from_openqa";
        assert_screen "$name-join-openqa-test_irc_from_openqa";
        assert_and_click "$name-join-channel-OK";

        # send a test message in IRC channel
        assert_screen "$name-main-window";
        enter_cmd "hello, this is openQA running $name with FIPS Enabled!";
        assert_screen "$name-message-sent-to-channel";
        enter_cmd "/quit I'll be back";
        assert_screen "$name-quit";
    }
    elsif (match_has_tag("$name-SASL-only-error")) {
        record_info('SASL required', 'The public IP of the current worker has been blacklisted on Libera, so a SASL connection would be required. https://progress.opensuse.org/issues/66697');
    }
}

sub run {
    select_console "root-console";

    my $name = ('hexchat');
    zypper_call("in $name");

    # we need to move the mouse in the top left corner as hexchat
    # opens it's window where the mouse is. mouse_hide() would move
    # it to the lower right where the pk-update-icon's passive popup
    # may suddenly cover parts of the dialog ... o_O
    select_console "x11";
    mouse_set(0, 0);

    if (my $url = get_var("XCHAT_URL")) {
        # Start up hexchat client and try to login into server
        x11_start_program("$name --url=$url", valid => 0);
        irc_login_send_message($name);
    }
    else {
        x11_start_program("$name", target_match => "$name-network-select");
        enter_cmd "freenode";

        # use ssl for all servers on this network
        assert_and_click "$name-edit-button";
        assert_screen ["$name-use-ssl-button", "$name-ssl-on"];
        # make sure SSL is enabled
        if (!match_has_tag("$name-ssl-on")) {
            assert_and_click "$name-use-ssl-button";
        }
        assert_and_click "$name-close-button";
        # start connect to server
        assert_and_click "$name-connect-button";
        irc_login_send_message($name);
    }
    send_key "alt-f4";
}

1;
