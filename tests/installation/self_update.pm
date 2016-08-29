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
    if (check_screen 'self-update-registration-server', 200) {
        if (get_var('SMT_URL')) {
            send_key 'alt-u';
        }
        send_key 'ret';
    }
}

1;
# vim: set sw=4 et:
