# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Change keyboard layout
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use caasp 'send_alt';

sub run {
    # Switch to UK keyboard
    send_alt 'kb_layout';
    send_key 'up';
    send_key 'ret' if check_var('VIDEOMODE', 'text');

    # Wait for keyboard switch before typing
    sleep 1;

    # Check that UK layout is active
    send_alt 'kb_test';
    type_string '~@#\"|';    # writes ¬"£#@~
    assert_screen 'keyboard-layout-uk';
    for (1 .. 6) { send_key 'backspace' }

    # Switch back to US keyboard
    send_alt 'kb_layout';
    send_key 'down';
    send_key 'ret' if check_var('VIDEOMODE', 'text');
}

1;
