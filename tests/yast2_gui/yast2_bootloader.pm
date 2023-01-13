# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-bootloader
# Summary: YaST2 UI test bootloader checks boot code option, kernel parameters,
#	graphical console, bootloader option, foreign OS and protect boot loader
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils 'type_string_slow_extended';
use version_utils 'is_sle';
use YaST::workarounds;

sub run {
    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11('bootloader', match_timeout => 120);

    #	boot code options
    assert_and_click 'yast2-bootloader_grub2';
    assert_and_click 'yast2-bootloader_not-managed';
    assert_screen 'yast2-bootloader_not-managed_warning';
    send_key 'alt-c';

    #	kernel parameters and use graphical console
    wait_still_screen 3;
    assert_and_click 'yast2-bootloader_kernel-parameters';
    assert_screen 'yast2-bootloader_kernel-parameters-switched';
    send_key 'alt-p';
    send_key 'end';
    assert_screen 'yast2-bootloader_use-graphical-console';

    #	bootloader options and set probe foreign OS, timeout
    assert_and_click 'yast2-bootloader_bootloader-options';
    assert_screen 'yast2-bootloader_bootloader-options-switched';
    send_key 'alt-b';
    wait_still_screen 3;
    send_key 'alt-t';
    type_string '16';

    #	default boot section
    if (is_sle('>=15-SP4')) {
        apply_workaround_bsc1204176('yast2-bootloader_default-boot-section') if (is_sle('>=15-SP4'));
        assert_and_click 'yast2-bootloader_default-boot-section';
    }
    else {
        assert_screen 'yast2-bootloader_default-boot-section_tw';
    }

    #	proctect boot loader with password
    assert_and_click 'yast2-bootloader_protect-bootloader-with-password';
    send_key 'alt-p';
    type_string_slow_extended('dummy-password');
    assert_screen 'yast2-bootloader_pwd_filled_up';
    send_key 'alt-y';
    type_string_slow_extended('dummy-password');

    # OK => Exit
    send_key "alt-o";
    assert_screen 'generic-desktop', 600;
}

1;
