# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable jeos-firstboot as required by openQA testsuite
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils 'zypper_call';

sub run {
    # Login with default credentials (root:linux)
    assert_screen('linux-login', 300);
    type_string("root\n",  wait_still_screen => 5);
    type_string("linux\n", wait_still_screen => 5);

    # Ensure YaST2-Firstboot is disabled, as we use jeos-firstboot in openQA
    assert_script_run("systemctl disable YaST2-Firstboot");

    # Install and enable jeos-firstboot
    zypper_call('in jeos-firstboot');
    assert_script_run("touch /var/lib/YaST2/reconfig_system");
    assert_script_run("systemctl enable jeos-firstboot");

    # Remove current root password
    assert_script_run("sed -i 's/^root:[^:]*:/root:*:/' /etc/shadow", 600);

    type_string("reboot\n");
}

1;
