# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot into MS Windows from grub
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use windows_utils;

sub run {
    assert_screen "grub-reboot-windows", 125;

    send_key "down";
    send_key "down";
    send_key "ret";

    wait_boot_windows;
}

1;
