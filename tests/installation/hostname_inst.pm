# SUSE's openQA tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Assert hostname in YaST Installer is set properly
# - Check if hostname matches the one defined on EXPECTED_INSTALL_HOSTNAME or is
# "install"
# - Save screenshot
# Maintainer: Michal Nowak <mnowak@suse.com>
# Tags: pr#11456, fate#319639

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils;

sub run {
    assert_screen "before-package-selection";
    select_console 'install-shell';
    # NICTYPE_USER_OPTIONS="hostname=myguest" causes a fake DHCP hostname provided by QEMU to SUT
    # 'install' is the default hostname if no hostname is get from environment
    # but, we may expect a different hostname (linuxrc, hostname, real DHCP server pushing a hostname)
    # from setting EXPECTED_INSTALL_HOSTNAME
    my $expected_install_hostname = get_var('EXPECTED_INSTALL_HOSTNAME', get_var('NICTYPE_USER_OPTIONS', 'install'));
    $expected_install_hostname =~ s/hostname=//;
    # Before SLE15-SP2, yast didn't take during installation the hostname by DHCP
    # See fate#319639
    if (is_sle('<15-SP2') && (script_run(qq{test "\$(hostname)" == "linux"}) == 0)) {
        record_soft_failure('bsc#1166778 - Default hostname in SLE15-SP1 is not "install"');
    } else {
        assert_script_run(qq{test "\$(hostname)" == "$expected_install_hostname"});
    }
    save_screenshot;
    # cleanup
    type_string "cd /\n";
    type_string "reset\n";
    select_console 'installation';
}

1;
