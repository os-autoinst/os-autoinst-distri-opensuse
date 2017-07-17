# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Pidgin: IRC
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1248849

use base "x11regressiontest";
use strict;
use testapi;


sub run {
    my ($self) = @_;
    my $CHANNELNAME = "susetesting";
    x11_start_program("pidgin");

    # Create account
    send_key "alt-a";
    sleep 2;
    send_key "spc";
    sleep 2;

    # Choose Protocol "IRC"
    send_key_until_needlematch 'pidgin-protocol-irc', 'down';
    send_key "ret";
    sleep 2;
    send_key "alt-u";
    sleep 1;
    type_string "$CHANNELNAME";
    sleep 2;
    send_key "alt-a";

    # Should create IRC account
    assert_screen 'pidgin-irc-account';

    # Close account manager
    send_key "ctrl-a";
    sleep 2;
    send_key "alt-c";
    sleep 15;    # need time to connect server

    # Warning of spoofing ip may appear
    if (check_screen("pidgin-spoofing-ip", 10)) {
        wait_screen_change {
            send_key "alt-tab";
        };
        wait_screen_change {
            send_key "ctrl-w";    # close it
        };
    }

    # Join a chat
    send_key "ctrl-c";
    sleep 2;

    type_string "#sledtesting";
    sleep 2;
    send_key "alt-j";

    # Should open sledtesting channel
    assert_screen 'pidgin-irc-sledtesting';

    # Send a message
    send_key "alt-tab";
    type_string "Hello from openQA\n";
    assert_screen 'pidgin-irc-msgsent';
    send_key "ctrl-w";
    sleep 2;

    # Cleaning
    $self->pidgin_remove_account;

    # Should not have any account and show welcome window
    assert_screen 'pidgin-welcome';

    # Exit
    send_key "alt-c";
    sleep 2;
    send_key "ctrl-q";
    sleep 2;
}

1;
# vim: set sw=4 et:
