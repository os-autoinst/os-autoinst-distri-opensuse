# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    send_key 'alt-d';    # open proposal settings
    if (!check_screen 'disabledhome', 5) {
        if (check_screen('inst-partition-radio-buttons', 5)) {    # detect whether new (Radio Buttons) YaST behaviour
            send_key 'alt-r';                                     # unselect separate home partition
        }
        else {
            send_key 'alt-p';                                     # unselect separate home partition
        }
    }
    assert_screen 'disabledhome';
    send_key 'alt-o';                                             # close proposal settings
}

1;
# vim: set sw=4 et:
