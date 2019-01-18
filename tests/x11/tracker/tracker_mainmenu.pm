# Tracker tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Tracker: Find an application with Search in the Main Menu
# Maintainer: Chingkai Chu <qkzhu@suse.com>
# Tags: tc#1503761

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    # enter 'Activities overview'
    send_key "super";
    assert_screen 'tracker-mainmenu-launched';

    # launch an app(tracker-needle) from 'Activities overview'
    type_string "tracker-needle";
    assert_screen 'tracker-mainmenu-search';
    send_key "ret";
    assert_screen 'tracker-needle-launched';
    send_key "alt-f4";    # close the app
}

1;
