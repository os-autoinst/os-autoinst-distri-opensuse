# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: First commit for pidgin cases. These cases should be test under good network condition.Otherwise,will be failed by timeout.
# G-Maintainer: nick wang <nwang@suse.com>

use base "x11regressiontest";
use strict;
use testapi;

# Case 1248855 - Pidgin: Add AIM Account
# Case 1248856 - Pidgin: Login to AIM Account and Send/Receive Message
sub run() {
    my $self      = shift;
    my $USERNAME  = "nooops_test3";
    my $USERNAME1 = "nooops_test4";
    my $DOMAIN    = "aim";
    my $PASSWD    = "opensuse";

    x11_start_program("pidgin");

    # Create account
    send_key "alt-a";
    sleep 2;
    send_key "spc";
    sleep 2;

    send_key_until_needlematch 'pidgin-protocol-aim', 'down';
    send_key "ret";
    sleep 2;
    send_key "alt-u";
    sleep 1;

    type_string $USERNAME. "@" . $DOMAIN . ".com";
    sleep 2;
    send_key "alt-p";
    sleep 1;
    type_string $PASSWD;
    sleep 2;
    send_key "alt-a";

    # Should create AIM account 1
    assert_screen 'pidgin-aim-account1';

    # Create another account
    send_key "ctrl-a";
    sleep 2;
    send_key "alt-a";
    sleep 2;
    send_key "alt-u";
    sleep 1;
    type_string $USERNAME1. "@" . $DOMAIN . ".com";
    sleep 2;
    send_key "alt-p";
    sleep 1;
    type_string "$PASSWD";
    sleep 2;
    send_key "alt-a";
    sleep 15;    # wait until account2 online

    # Should have AIM accounts 1 and 2
    assert_screen 'pidgin-aim-account2';

    # Close account manager
    send_key "ctrl-a";
    sleep 2;
    send_key "alt-c";
    sleep 2;

    # Open a chat
    send_key "tab";
    sleep 2;
    send_key_until_needlematch 'pidgin-aim-online-buddy', 'down';
    sleep 2;
    send_key "ret";
    sleep 2;
    type_string "hello world!\n";

    # Should see "hello world!" in screen.
    assert_screen 'pidgin-aim-sentmsg';
    send_key "ctrl-tab";
    assert_screen 'pidgin-aim-receivedmsg';
    sleep 2;

    # Cleaning
    # Close the conversation
    send_key "ctrl-w";
    sleep 2;
    send_key "ctrl-w";
    sleep 2;

    # Remove one account
    send_key "ctrl-a";
    sleep 2;
    send_key "right";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "alt-d";
    sleep 2;
    send_key "alt-d";
    sleep 2;

    # Remove the other account
    send_key "ctrl-a";
    sleep 2;
    send_key "right";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "alt-d";
    sleep 2;
    send_key "alt-d";

    # Should not have any account
    assert_screen 'pidgin-welcome';

    # Exit
    send_key "alt-c";
    sleep 2;
    send_key "ctrl-q";
    sleep 2;
}

1;
# vim: set sw=4 et:
