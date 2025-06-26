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
        assert_and_click "$name-join-channel";
        # clear the original '#hexchat' channel name
        wait_still_screen 2;
        wait_screen_change { send_key 'ctrl-a' };
        wait_screen_change { send_key "delete" };
        enter_cmd "#openqa-test_irc_from_openqa";
        assert_screen "$name-join-openqa-test_irc_from_openqa";
        assert_and_click "$name-join-channel-OK";
        assert_screen "$name-main-window";
        enter_cmd "hello, this is openQA running $name with FIPS Enabled!";
        assert_screen "$name-message-sent-to-channel";
        enter_cmd "/quit I'll be back";
        assert_screen "$name-quit";
    }
    elsif (match_has_tag("$name-SASL-only-error")) {
        record_info('SASL required', 'The public IP of the current worker has been blacklisted, so a SASL connection would be required. https://progress.opensuse.org/issues/66697');
    }
}

sub enable_ssl_for_network {
    my ($name) = @_;
    assert_and_click "$name-edit-button";
    assert_screen ["$name-use-ssl-button", "$name-ssl-on"];
    match_has_tag("$name-ssl-on") or assert_and_click "$name-use-ssl-button";
    assert_and_click "$name-close-button";
}

sub run {
    select_console "root-console";
    my $name = 'hexchat';
    zypper_call("in $name");
    select_console "x11";
    my $server_address = get_var("XCHAT_URL");
    if ($server_address) {
        x11_start_program("$name --url=$server_address", valid => 0);
        irc_login_send_message($name);
    }
    else {
        x11_start_program("$name", target_match => "$name-network-select");
        enter_cmd "Rizon";
        enable_ssl_for_network($name);
        assert_and_click "$name-connect-button";
        irc_login_send_message($name);
    }
    send_key "alt-f4";
}

1;
