# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare and trigger the reboot into the installed system
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use base 'y2logsstep';
use testapi;
use utils;

sub run {
    select_console 'installation';
    wait_screen_change {
        send_key 'alt-o';    # Reboot
    };

    power_action('reboot', observe => 1, keepconsole => 1);
}

1;
# vim: set sw=4 et:
