# SUSE's openQA tests
#
# Copyright 2021-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Combine modules with the actions that are required after reboot.
# Reconnect management-consoles on remote backends and then process GRUB.
# The solution is implemented to use in declarative scheduling to reduce
# usage of complex conditions.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use grub_utils qw(grub_test);
use testapi;
use Utils::Architectures;
use Utils::Backends;
use utils qw(reconnect_mgmt_console);

sub run {
    if (is_remote_backend) {
        record_info 'Remote', 'Reconnect mgmt console';
        reconnect_mgmt_console();
    }

    unless (is_s390x || is_ipmi) {
        record_info 'Handle GRUB';
        grub_test();
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
