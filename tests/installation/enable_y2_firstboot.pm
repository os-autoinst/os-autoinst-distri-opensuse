# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable YaST2 Firstboot module - Desktop workstation configuration utility
# Doc: https://en.opensuse.org/YaST_Firstboot
# Maintainer: Martin Loviska <mloviska@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call clear_console);

sub run {
    select_console 'root-console';
    zypper_call "in yast2-firstboot";
    assert_script_run 'touch /var/lib/YaST2/reconfig_system';
    clear_console;
}

1;
