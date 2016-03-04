# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

# Add SocketCAN kernel driver without problems
# https://fate.suse.com/317131
sub run() {
    assert_script_run "modprobe peak_pci";
    assert_script_run "lsmod | grep ^peak_pci";
}

1;
