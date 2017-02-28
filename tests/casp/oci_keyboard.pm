# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
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

sub run() {
    # Switch to UK
    send_key 'alt-e';
    send_key 'up';

    # Check that UK layout is active
    send_key 'alt-g';
    type_string '~@#\"|';    # writes ¬"£#@~
    assert_screen 'keyboard-layout-uk';
    send_key 'ctrl-a';
    send_key 'delete';

    # Switch to US
    send_key 'alt-e';
    send_key 'down';
}

1;
# vim: set sw=4 et:
