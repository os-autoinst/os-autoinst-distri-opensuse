# SUSE's openQA tests
#
# Copyright Â© 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base 'y2logsstep';
use testapi;

sub run() {

    assert_screen 'scc-registration', 100;
    send_key 'alt-w';    # press network configuration button
    assert_screen 'installation-network-settings';
    send_key 'alt-s';    # select Hostname/DNS tab
    if (!check_screen 'installation-network-settings-hostname-susetest', 5) {
        send_key 'alt-t';    # select hostname field
        type_string 'susetest';
    }
    sleep 1;
    save_screenshot;
    send_key 'alt-n';        # next
}

1;
# vim: set sw=4 et:
