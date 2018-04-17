# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable probe foreign os for SLE dual boot scenario
# Maintainer: Grace Wang <gwang@suse.com>
# Tags: bsc#1089516

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {
    record_soft_failure('bsc#1089516');
    # Verify Installation Settings overview is displayed as starting point
    assert_screen "installation-settings-overview-loaded";

    # Select section booting on Installation Settings overview (video mode)
    send_key_until_needlematch 'booting-section-selected', 'tab';
    assert_screen 'booting-section-selected';
    send_key 'ret';

    assert_screen([qw(inst-bootloader-settings inst-bootloader-settings-first_tab_highlighted)]);
    # Depending on an optional button "release notes" we need to press "tab"
    # to go to the first tab
    send_key 'tab' unless match_has_tag 'inst-bootloader-settings-first_tab_highlighted';
    send_key_until_needlematch 'inst-bootloader-options-highlighted', 'right';
    assert_screen 'installation-bootloader-options';
    # Enable Probe Forengn OS
    send_key 'alt-b';
    assert_screen 'enable_probe_foreignos';
    wait_still_screen(3);

    send_key 'alt-o';
    assert_screen 'installation-settings-overview-loaded';
}

1;
# vim: set sw=4 et:
