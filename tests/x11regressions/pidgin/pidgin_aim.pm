# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Pidgin: Add AIM Account; Login to AIM Account and Send/Receive Message
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1248855, tc#1248856

use base "x11regressiontest";
use strict;
use testapi;

sub run {
    my ($self)    = @_;
    my $USERNAME  = "nooops_test3";
    my $USERNAME1 = "nooops_test4";
    my $DOMAIN    = "aim";
    my $PASSWD    = "opensuse";

    x11_start_program("pidgin");

    # Create account
    wait_screen_change { send_key 'alt-a' };
    wait_screen_change { send_key 'spc' };
    send_key_until_needlematch 'pidgin-protocol-aim', 'down';
    wait_screen_change { send_key 'ret' };
    wait_screen_change { send_key 'alt-u' };
    type_string $USERNAME. "@" . $DOMAIN . ".com";
    wait_still_screen(1);
    wait_screen_change { send_key 'alt-p' };
    type_string $PASSWD;
    wait_screen_change { send_key "alt-a" };

    # Should create AIM account 1
    assert_screen 'pidgin-aim-account1';

    # Create another account
    wait_screen_change { send_key 'ctrl-a' };
    wait_screen_change { send_key 'alt-a' };
    wait_screen_change { send_key 'alt-u' };
    wait_screen_change { type_string $USERNAME1. "@" . $DOMAIN . ".com" };
    wait_screen_change { send_key "alt-p" };
    wait_screen_change { type_string "$PASSWD" };
    wait_screen_change { send_key "alt-a" };
    # Should have AIM accounts 1 and 2
    assert_screen 'pidgin-aim-account2';

    # Close account manager
    wait_screen_change { send_key "ctrl-a" };
    wait_screen_change { send_key "alt-c" };

    # Open a chat
    wait_screen_change { send_key "tab" };
    send_key_until_needlematch 'pidgin-aim-online-buddy', 'down';
    wait_screen_change { send_key "ret" };
    type_string "hello world!\n";

    # Should see "hello world!" in screen.
    assert_screen 'pidgin-aim-sentmsg';
    send_key "ctrl-tab";
    assert_screen 'pidgin-aim-receivedmsg';

    # Cleaning
    # Close the conversation
    wait_screen_change { send_key "ctrl-w" };
    send_key "ctrl-w";

    # Remove both accounts
    for (1 .. 2) {
        $self->pidgin_remove_account;
    }

    # Should not have any account
    assert_screen 'pidgin-welcome';

    # Exit
    wait_screen_change { send_key "alt-c" };
    send_key "ctrl-q";
}

1;
# vim: set sw=4 et:
