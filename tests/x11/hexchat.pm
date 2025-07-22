# Copyright 2015-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: hexchat
# Summary: Test both hexchat and xchat in one test
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "x11test";
use testapi;
use utils;

sub run {
    my $name = ref($_[0]);
    ensure_installed($name);
    x11_start_program($name, target_match => "$name-network-select");
    enter_cmd "Libera";
    assert_and_click "hexchat-nick-$username";
    send_key 'home';
    send_key_until_needlematch 'hexchat-nick-empty', 'delete';
    type_string "openqa" . random_string(5);
    assert_and_click "$name-connect-button";
    my @tags = ("$name-connection-complete-dialog", "$name-SASL-only-error");
    assert_screen \@tags;
    if (match_has_tag("$name-connection-complete-dialog")) {
        assert_and_click "$name-join-channel";
        enter_cmd "openqa";
        send_key 'ret';
        assert_screen "$name-main-window";
        enter_cmd "hello, this is openQA running $name!";
        assert_screen "$name-message-sent-to-channel";
        enter_cmd "/quit I'll be back";
        assert_screen "$name-quit", 60;
    }
    elsif (match_has_tag("$name-SASL-only-error")) {
        record_info('SASL required', 'The public IP of the current worker has been blacklisted on Libera, so a SASL connection would be required. https://progress.opensuse.org/issues/66697');
    }
    send_key 'alt-f4';
}

1;
