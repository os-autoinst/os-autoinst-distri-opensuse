# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure software watchdog
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use hacluster;
use lockapi;
use utils;

sub run {
    my $module = 'softdog';

    # Configure the software watchdog
    script_run "echo $module > /etc/modules-load.d/$module.conf";
    script_run "echo 'options $module soft_margin=$softdog_timeout' > /etc/modprobe.d/99-$module.conf";
    systemctl 'restart systemd-modules-load.service';

    # Softdog module needs to be loaded
    # Note: 'grep -q' is not always working, because it can exits with RC=141 due to the pipe...
    type_string "dmesg | grep -i $module\n";
    assert_script_run "lsmod | grep $module";

    # Keep the screenshot for this test
    save_screenshot;
}

1;
