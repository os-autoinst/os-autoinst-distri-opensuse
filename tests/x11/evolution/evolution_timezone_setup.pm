# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

#testcase 5255-1503908:Evolution: setup timezone

# Package: evolution
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
    my $self = shift;
    my $account = "internal_account";
    my $hostname = get_var('HOSTNAME');
    if ($hostname eq 'client') {
        $account = "internal_account_C";
    }
    else {
        $account = "internal_account_A";
    }

    $self->setup_pop($account);
    # Set up timezone via: Edit->Preference->calendor and task->uncheck "use
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
    assert_screen "mercator-zoomed-in";
    # Change timezone to Shanghai
    send_key "alt-s";
    wait_still_screen(2);
    send_key_until_needlematch('timezone-asia', 'ret', 11, 2);
    send_key "right";
    wait_still_screen(2);
    send_key_until_needlematch("timezone-shanghai", "up", 21, 1);
    send_key "ret";
    assert_screen "asia-shanghai-timezone-setup";
    send_key "alt-o";
    wait_still_screen;
    send_key "alt-f4";
    wait_still_screen;
    send_key "alt-f4";
}

1;
