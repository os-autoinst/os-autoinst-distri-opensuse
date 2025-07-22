# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pidgin
# Summary: Pidgin: IRC
# - Launch pidgin
# - Create a new account, type IRC, nickname "susetesting"
# - Handle ip spoofing and ctcp warning
# - Join channel "#sledtesting" and check
# - Send message "Hello from openQA" and check
# - Close chat window
# - Cleanup
# Maintainer: Grace Wang <grace.wang@suse.com>
# Tags: tc#1248849

use base "x11test";
use testapi;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    my ($self) = @_;
    my $CHANNELNAME = "susetesting";
    my $SERVERNAME = "irc.libera.chat";
    x11_start_program('pidgin');

    # Focus the welcome window in SLE15
    assert_and_click("pidgin-welcome-not-focused") if is_sle('>=15') or is_tumbleweed;

    # Create account
    send_key "alt-a";
    wait_still_screen 2;
    send_key "spc";
    wait_still_screen 2;

    # Choose Protocol "IRC"
    send_key_until_needlematch 'pidgin-protocol-irc', 'down';
    send_key "ret";
    wait_still_screen 2;
    send_key "alt-u";
    wait_still_screen 2;
    type_string "$CHANNELNAME";
    wait_still_screen 2;
    send_key "alt-s";
    type_string "$SERVERNAME";
    wait_still_screen 2;
    send_key "alt-a";

    # Should create IRC account, close account manager
    assert_and_click 'pidgin-irc-account';

    # IP spoofing or CTCP Version and scan warnings may appear
    my @tags = qw(pidgin-ready pidgin-spoofing-ip pidgin-ctcp-version pidgin-SASL-only-error);
    assert_screen \@tags;    # wait until connection established
    wait_still_screen 5;    # give some time for warnings to pop-up
    while (check_screen('pidgin-spoofing-ip') || check_screen('pidgin-ctcp-version')) {
        send_key is_sle('<15') ? "alt-tab" : "alt-`";    # focus on warning
        wait_still_screen 2;
        send_key "ctrl-w";    # close it
        wait_still_screen 2;
    }
    if (match_has_tag("pidgin-SASL-only-error")) {
        record_info('SASL required', 'The public IP of the current worker has been blacklisted on Libera, so a SASL connection would be required. https://progress.opensuse.org/issues/102653');
    } else {
        assert_screen "pidgin-ready";
        # Join a chat
        send_key "ctrl-c";
        wait_still_screen 2;
        type_string "#sledtesting";
        wait_still_screen 2;
        send_key "alt-j";

        # Should open sledtesting channel
        assert_screen 'pidgin-irc-sledtesting';

        # Send a message
        send_key is_sle('<15') ? "alt-tab" : "alt-`";
        wait_still_screen 2;
        enter_cmd "Hello from openQA";
        assert_screen 'pidgin-irc-msgsent';
        send_key "ctrl-w";
        wait_still_screen 2;


    }
    # Cleaning
    $self->pidgin_remove_account;

    # Should not have any account and show welcome window
    assert_screen 'pidgin-welcome';

    # Exit
    send_key "alt-c";
    wait_still_screen 2;
    send_key "ctrl-q";
}

1;
