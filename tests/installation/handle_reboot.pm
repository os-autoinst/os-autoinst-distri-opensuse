# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Combine modules with the actions that are required after reboot.
# Reconnect management-consoles on remote backends and then process GRUB.
# The solution is implemented to use in declarative scheduling to reduce
# usage of complex conditions.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use grub_utils qw(grub_test);
use testapi;
use Utils::Backends 'is_remote_backend';
use utils qw(reconnect_mgmt_console);

sub run {
    if (is_remote_backend) {
        record_info 'Reconnect mgmt console';
        reconnect_mgmt_console();
    }

    unless (check_var('ARCH', 's390x') || check_var('BACKEND', 'ipmi')) {
        record_info 'Handle GRUB';
        grub_test();
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
