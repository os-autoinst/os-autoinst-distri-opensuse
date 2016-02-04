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
    sleep 2;
    assert_screen "preparing-disk-select-iscsi-disk";
    send_key "alt-1";    # select ISCSI disk
    send_key "alt-n";    # next
    assert_screen "preparing-disk-install-on";
    send_key "alt-e";    # use entire iscsi disk
    send_key "alt-n";    # next
    assert_screen "edit-proposal-settings";
}

1;
# vim: set sw=4 et:
