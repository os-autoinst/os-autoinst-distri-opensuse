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
    assert_screen 'disk-activation';
    send_key 'alt-i';    # configure iscsi disk
    assert_screen 'iscsi-overview', 100;
    send_key 'alt-i';    # iBFT tab
    assert_screen 'iscsi-ibft';
    send_key 'alt-o';    # OK
    assert_screen 'disk-activation';
    send_key 'alt-n';    # next
}

1;
# vim: set sw=4 et:
