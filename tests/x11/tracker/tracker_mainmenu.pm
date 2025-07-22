# Tracker tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Tracker: Find an application with Search in the Main Menu
# Maintainer: Zhaocong Jia <zcjia@suse.com> Grace Wang <grace.wang@suse.com>
# Tags: tc#1503761

use base "x11test";
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
