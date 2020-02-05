# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#testcase 5255-1503908:Evolution: setup timezone

# Summary: tc#1503908: evolution_timezone_setup
# - Open edit menu, preferences
# - Open Calendar and Tasks
# - Click on timezone selection
# - On the map, select Shanghai timezone
# - Select OK
# - Close Evolution
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;

sub run {
    my $self    = shift;
    my $account = "internal_account_A";
    $self->setup_pop($account);

    # Set up timezone via: Edit->Preference->calendar and task->uncheck "use
    # sYstem timezone", then select
    send_key "alt-e";
    send_key_until_needlematch "evolution-preference-highlight", "down";
    send_key "ret";
    assert_screen "evolution-preference";
    send_key_until_needlematch "evolution-calendorAtask", "down";
    send_key "alt-y";
    assert_and_click "timezone-select";
    assert_screen "evolution-selectA-timezone";
    assert_and_click "mercator-projection";
    assert_and_click("mercator-zoomed-in-clicked");
    # Change timezone to Shanghai
    if (check_screen("timezone-asia")) {
        send_key("right");
        send_key_until_needlematch("timezone-yerevan", "end");
        assert_and_click("timezone-yerevan");
    }
    else {
        send_key_until_needlematch("timezone-asia", "down");
        send_key "right";
        send_key_until_needlematch("timezone-asia-shanghai", "up");
        send_key "ret";
    }
    assert_and_click("asia-shanghai-timezone-setup-click");
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
}

1;
