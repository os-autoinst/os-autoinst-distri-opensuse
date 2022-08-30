# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify timezone settings page and proceed to next page
# - Proceed only if in timezone selection screen
# - If TIMEZONE is "beijing", select timezone-beijing in timezone selection
# screen
# - Select next
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils 'noupdatestep_is_applicable';

sub run {
    assert_screen "inst-timezone", 125 || die 'no timezone';
    # performance ci need install with timezone Asia-beijing
    if (check_var('TIMEZONE', 'beijing')) {
        send_key_until_needlematch("timezone-Asia", "up", 21, 1);
        send_key 'tab';
        send_key_until_needlematch("timezone-beijing", "down", 21, 1);
    } elsif (check_var('TIMEZONE', 'shanghai')) {
        send_key_until_needlematch("timezone-Asia", "up", 21, 1);
        send_key 'tab';
        send_key "end";
        send_key_until_needlematch("timezone-shanghai", "up", 101, 1);
    }
    # Unpredictable hotkey on kde live distri, click button. See bsc#1045798
    if (noupdatestep_is_applicable() && get_var("LIVECD")) {
        assert_and_click 'next-button';
    }
    else {
        send_key $cmd{next};
    }
}

1;
