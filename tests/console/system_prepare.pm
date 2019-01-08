# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Execute SUT changes which should be permanent
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'consoletest';
use testapi;
use utils;
use Utils::Backends 'use_ssh_serial_console';
use version_utils qw(is_sle);
use serial_terminal 'add_serial_console';
use bootloader_setup qw(change_grub_config grub_mkconfig);
use strict;

sub run {
    my ($self) = @_;
    check_var('BACKEND', 'ipmi') ? use_ssh_serial_console : select_console 'root-console';

    ensure_serialdev_permissions;

    # Configure serial consoles for virtio support
    # poo#18860 Enable console on hvc0 on SLES < 12-SP2
    # poo#44699 Enable console on hvc1 to fix login issues on ppc64le
    if (get_var('VIRTIO_CONSOLE')) {
        if (is_sle('<12-SP2')) {
            add_serial_console('hvc0');
        }
        elsif (get_var('OFW')) {
            add_serial_console('hvc1');
        }
    }

    # bsc#997263 - VMware screen resolution defaults to 800x600
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        change_grub_config('=.*', '=1024x768x32', 'GFXMODE=');
        change_grub_config('=.*', '=1024x768x32', 'GFXPAYLOAD_LINUX=');
        grub_mkconfig;
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
