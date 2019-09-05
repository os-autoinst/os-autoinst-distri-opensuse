# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Pidgin: IRC
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1248849

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    my ($self) = @_;
    my $CHANNELNAME = "susetesting";
    x11_start_program('pidgin');

    # Focus the welcome window in SLE15
    assert_and_click("pidgin-welcome-not-focused") if is_sle('>=15') or is_tumbleweed;

    # Create account
    wait_screen_change { send_key "alt-a" };
    wait_screen_change { send_key "spc" };

    # Choose Protocol "IRC"
    send_key_until_needlematch 'pidgin-protocol-irc', 'down';
    wait_screen_change { send_key "ret" };
    wait_screen_change { send_key "alt-u" };
    wait_screen_change { type_string "$CHANNELNAME" };
    wait_screen_change { send_key "alt-a" };

    # Should create IRC account, close account manager
    assert_and_click 'pidgin-irc-account';

    # Warning of spoofing ip may appear
    assert_screen([qw(pidgin-spoofing-ip pidgin-ready)]);
    if (match_has_tag('pidgin-spoofing-ip')) {
        wait_screen_change {
            send_key is_sle('<15') ? "alt-tab" : "alt-`";
        };
        wait_screen_change {
            send_key "ctrl-w";    # close it
        };
    }

    # CTCP Version and warning about scan may appear
    assert_screen([qw(pidgin-ctcp-version pidgin-ready)]);
    if (match_has_tag('pidgin-ctcp-version')) {
        wait_screen_change { send_key "ctrl-w" };    # close it
        assert_screen("pidgin-ready");               # Assure that pidgin is ready
    }

    # Join a chat
    wait_screen_change { send_key "ctrl-c" };
    wait_screen_change { type_string "#sledtesting" };
    send_key "alt-j";

    # Should open sledtesting channel
    assert_screen 'pidgin-irc-sledtesting';

    # Send a message
    send_key is_sle('<15') ? "alt-tab" : "alt-`";
    type_string "Hello from openQA\n";
    assert_screen 'pidgin-irc-msgsent';
    wait_screen_change { send_key "ctrl-w" };

    # Cleaning
    $self->pidgin_remove_account;

    # Should not have any account and show welcome window
    assert_screen 'pidgin-welcome';

    # Exit
    wait_screen_change { send_key "alt-c" };
    send_key "ctrl-q";
}

1;
