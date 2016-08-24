# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    send_key "alt-c";    # create partition setup
    wait_still_screen(2);
    assert_screen "preparing-disk-select-iscsi-disk";
    send_key "alt-1";    # select ISCSI disk
    send_key $cmd{next};
    if (check_screen "preparing-disk-use-entire-disk-button", 10) {
        send_key "alt-e";    # use entire iscsi disk
    }
    assert_screen "preparing-disk-overview";
    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
