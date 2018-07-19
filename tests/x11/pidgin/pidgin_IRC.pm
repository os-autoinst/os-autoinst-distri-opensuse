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
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    my $CHANNELNAME = "susetesting";
    x11_start_program('pidgin');

    # Focus the welcome window in SLE15
    assert_and_click("pidgin-welcome-not-focused") if is_sle('>=15');

    # Create account
    wait_screen_change { send_key "alt-a" };
    wait_screen_change { send_key "spc" };

    # Choose Protocol "IRC"
    send_key_until_needlematch 'pidgin-protocol-irc', 'down';
    wait_screen_change { send_key "ret" };
    wait_screen_change { send_key "alt-u" };
    wait_screen_change { type_string "$CHANNELNAME" };
    wait_screen_change { send_key "alt-a" };

    # Should create IRC account
    assert_screen 'pidgin-irc-account';

    # Close account manager
    wait_screen_change { send_key "ctrl-a" };
    wait_screen_change { send_key "alt-c" };

    # Warning of spoofing ip may appear
    assert_screen([qw(pidgin-spoofing-ip pidgin-irc-sledtesting)]);
    if (match_has_tag('pidgin-spoofing-ip')) {
        wait_screen_change {
            send_key "alt-tab";
        };
        wait_screen_change {
            send_key "ctrl-w";    # close it
        };
    }

    # Join a chat
    wait_screen_change { send_key "ctrl-c" };
    wait_screen_change { type_string "#sledtesting" };
    send_key "alt-j";

    # Should open sledtesting channel
    # we need to switch tabs on SLE15
    if (is_sle('>=15')) {
        assert_and_click 'pidgin-irc-sledtesting';
    }
    else {
        assert_screen 'pidgin-irc-sledtesting';
    }

    # Send a message
    send_key "alt-tab";
    type_string "Hello from openQA\n";
    assert_screen 'pidgin-irc-msgsent';
    wait_screen_change { send_key "ctrl-w" };

    # There is another tab to close on SLE15
    wait_screen_change { send_key "ctrl-w" } if is_sle('>=15');

    # Cleaning
    $self->pidgin_remove_account;

    # Should not have any account and show welcome window
    assert_screen 'pidgin-welcome';

    # Exit
    wait_screen_change { send_key "alt-c" };
    send_key "ctrl-q";
}

1;
