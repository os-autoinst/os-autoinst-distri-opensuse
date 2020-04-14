# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Execute SUT changes which should be permanent
# - Grant permissions on serial device
# - Add hvc0/hvc1 to /etc/securetty
# - Register modules if SCC_ADDONS, MEDIA_UPGRADE and in Regression flavor
# are defined
# - If system is vmware, set resolution to 1024x768 (and write to grub)
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'consoletest';
use testapi;
use utils;
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

    # Register the modules after media migration, so it can do regession
    if (get_var('SCC_ADDONS') && get_var('MEDIA_UPGRADE') && (get_var('FLAVOR') =~ /Regression/)) {
        add_suseconnect_product(uc get_var('SLE_PRODUCT'), undef, undef, "-r " . get_var('SCC_REGCODE') . " --url " . get_var('SCC_URL'), 300, 1);
        if (is_sle('15+') && check_var('SLE_PRODUCT', 'sles')) {
            add_suseconnect_product(get_addon_fullname('base'),      undef, undef, undef, 300, 1);
            add_suseconnect_product(get_addon_fullname('serverapp'), undef, undef, undef, 300, 1);
        }
        if (is_sle('15+') && check_var('SLE_PRODUCT', 'sled')) {
            add_suseconnect_product(get_addon_fullname('base'),    undef, undef, undef,                             300, 1);
            add_suseconnect_product(get_addon_fullname('desktop'), undef, undef, undef,                             300, 1);
            add_suseconnect_product(get_addon_fullname('we'),      undef, undef, "-r " . get_var('SCC_REGCODE_WE'), 300, 1);
            add_suseconnect_product(get_addon_fullname('python2'), undef, undef, undef,                             300, 1);
        }
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

    # Save output info to logfile
    if (is_sle) {
        my $out = script_output("SUSEConnect --status-text", proceed_on_failure => 1);
        diag "SUSEConnect --status-text: $out";
        assert_script_run "SUSEConnect --status-text | grep -v 'Not Registered'" unless get_var('MEDIA_UPGRADE');
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
