# SUSE's openQA tests - FIPS tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: FIPS : hexchat_ssl
# Maintainer: Ben Chou <bchou@suse.com>
# Tags: poo#49139 , poo#49136 , poo#52796

use base "x11test";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

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
        x11_start_program("$name --url=$url", target_match => "$name-main-window");
    }
    else {
        x11_start_program("$name", target_match => "$name-network-select");
        type_string "freenode\n";

        # use ssl for all servers on this network
        assert_and_click "$name-edit-button";
        assert_screen ["$name-use-ssl-button", "$name-ssl-on"];
        if (!match_has_tag("$name-ssl-on")) {
            assert_and_click "$name-use-ssl-button";
        }
        assert_and_click "$name-close-button";

        assert_and_click "$name-connect-button";
        assert_screen "$name-connection-complete-dialog";
        assert_and_click "$name-join-channel";

        send_key "ctrl-a";
        send_key "delete";
        type_string "#openqa-test_irc_from_openqa\n";
        assert_screen "$name-join-openqa-test_irc_from_openqa";
        send_key "ret";
    }
    assert_screen "$name-main-window";
    type_string "hello, this is openQA running $name with FIPS Enabled!\n";
    assert_screen "$name-message-sent-to-channel";
    type_string "/quit I'll be back\n";
    assert_screen "$name-quit";
    send_key "alt-f4";
}

1;
