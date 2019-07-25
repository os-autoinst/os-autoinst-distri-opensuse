# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
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
use version_utils 'is_sle';
use serial_terminal 'add_serial_console';
use bootloader_setup qw(change_grub_config grub_mkconfig);
use registration;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    select_console 'root-console';

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

    # Register the modules after media migration, only for sle<15
    # poo#54131 [SLE][Migration][SLE12SP5]test fails in system_prepare -
    # media upgrade need add modules after migration
    if (get_var('SCC_ADDONS') && is_sle('<15') && get_var('MEDIA_UPGRADE') && get_var('KEEP_REGISTERED')) {
        assert_script_run 'SUSEConnect --url ' . get_required_var('SCC_URL') . ' -r ' . get_required_var('SCC_REGCODE');
        my $myaddons = get_var('SCC_ADDONS');
        # After media upgrade, system don't include ltss extension
        $myaddons =~ s/ltss,?//g;
        if ($myaddons ne '') {
            register_addons_cmd($myaddons);
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
