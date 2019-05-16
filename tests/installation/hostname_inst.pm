# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Assert hostname in YaST Installer is set properly
# Maintainer: Michal Nowak <mnowak@suse.com>
# Tags: pr#11456, fate#319639

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    assert_screen "before-package-selection";
    select_console 'install-shell';
    if (my $expected_install_hostname = get_var('EXPECTED_INSTALL_HOSTNAME')) {
        # EXPECTED_INSTALL_HOSTNAME contains expected hostname YaST installer
        # got from environment (DHCP, 'hostname=' as a kernel cmd line argument
        assert_script_run "test \"\$(hostname)\" == \"$expected_install_hostname\"";
    }
    else {
        # 'install' is the default hostname if no hostname is get from environment
        assert_script_run 'test "$(hostname)" == "install"';
    }
    save_screenshot;
    # cleanup
    type_string "cd /\n";
    type_string "reset\n";
    select_console 'installation';
}

1;
