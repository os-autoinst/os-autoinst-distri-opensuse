# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable grub timeout from the Installer
#   in order to ensure tests do not skip over it.
# - Enter bootloader configuration option during install (unless is update)
# - Set grub timeout to "-1" (60 if older than sle12sp1)
# - Save screenshot
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_upgrade);
use Utils::Architectures;

sub run {
    my ($self) = shift;

    # Verify Installation Settings overview is displayed as starting point
    assert_screen "installation-settings-overview-loaded", 90;

    if (check_var('VIDEOMODE', 'text')) {
        # Select section booting on Installation Settings overview on text mode
        send_key $cmd{change};
        assert_screen 'inst-overview-options';
        is_upgrade() ? send_key 'alt-t' : send_key 'alt-b';
    }
    else {
        # Select section booting on Installation Settings overview (video mode)
        send_key_until_needlematch 'booting-section-selected', 'tab', 26, 1;
        send_key 'ret';
    }

    # Config bootloader is not be supported during an upgrade
    # Add exception for SLES11SP4 base update, configure grub for this scenario
    if (is_upgrade && (!is_sle('<15') || !is_leap('<15.0')) && (!check_var('HDDVERSION', '11-SP4'))) {
        assert_screen([qw(bootloader-config-unsupport inst-bootloader-settings inst-bootloader-settings-first_tab_highlighted)]);
        if (match_has_tag 'bootloader-config-unsupport') {
            send_key 'ret';
            return;
        }
        if (!get_var('SOFTFAIL_1129504') && is_upgrade && is_sle) {
            record_info('Bootloader conf', 'Workaround for bsc#1129504 grub2 timeout is too fast', result => 'softfail');
            send_key 'alt-c';
            return;
        }
    }
    assert_screen([qw(inst-bootloader-settings inst-bootloader-settings-first_tab_highlighted)]);
    # Depending on an optional button "release notes" we need to press "tab"
    # to go to the first tab
    send_key 'tab' unless match_has_tag 'inst-bootloader-settings-first_tab_highlighted';

    # Seems like difference between UEFI and Legacy for sle15sp5+.
    my $bootloader_shortcut = (is_x86_64) ? ((check_var('UEFI', '1')) ? 'alt-t' : 'alt-r') : 'alt-t';    # Seems now the bootloader shortcut is a different one
    send_key_until_needlematch 'inst-bootloader-options-highlighted', is_sle('15-SP5+') ? $bootloader_shortcut : 'right';
    assert_screen 'installation-bootloader-options';
    # Select Timeout dropdown box and disable
    send_key 'alt-t';
    wait_still_screen(1);
    my $timeout = "-1";
    # SLE-12 GA only accepts positive integers in range [0,300]
    $timeout = "60" if is_sle('<12-SP1');
    $timeout = "90" if (get_var("REGRESSION", '') =~ /xen|kvm|qemu/);
    type_string $timeout;

    wait_still_screen(1);
    # ncurses uses blocking modal dialog, so press return is needed
    send_key 'ret' if check_var('VIDEOMODE', 'text');

    wait_still_screen(1);
    save_screenshot;
    send_key $cmd{ok};
    # Adapting system setting needs longer time in case of installing/upgrading with multi-addons
    assert_screen 'installation-settings-overview-loaded', 220;
}

1;
