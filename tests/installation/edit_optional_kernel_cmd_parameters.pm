# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Set optional kernel cmd parameters in the installer
#   Is required in some scenarios to disable plymouth, for instance.
#   All default parameters are removed before entering requested settings.
#   Using OPT_KERNEL_PARAMS to get wanted boot options.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_upgrade);

sub run {
    my ($self) = shift;

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-c';
        assert_screen 'inst-overview-options';
        send_key 'alt-b';
        assert_screen 'installation-bootloader-config';
        send_key 'alt-k';
        assert_screen 'installation-kernel-parameters';
        send_key 'alt-p';
        wait_still_screen(1);
    }
    else {
        # Verify Installation Settings overview is displayed as starting point
        assert_screen "installation-settings-overview-loaded";

        # Select section booting on Installation Settings overview (video mode)
        send_key_until_needlematch 'booting-section-selected', 'tab';
        send_key 'ret';

        assert_screen([qw(inst-bootloader-settings inst-bootloader-settings-first_tab_highlighted)]);
        # Depending on an optional button "release notes" we need to press "tab"
        # to go to the first tab
        send_key 'tab' unless match_has_tag 'inst-bootloader-settings-first_tab_highlighted';
        send_key_until_needlematch 'inst-kernel-parameters-highlighted', 'right';
        assert_screen 'installation-kernel-parameters';
        # Select Timeout dropdown box and disable
        send_key 'alt-p';
        wait_still_screen(1);
        # clean up the field
        send_key "backspace";
        wait_still_screen(1);
    }
    # type default parameters
    type_string_slow(get_var('OPT_KERNEL_PARAMS'));
    save_screenshot;
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-o';
    } else {
        send_key $cmd{ok};
    }
    # Adapting system setting needs longer time in case of installing/upgrading with multi-addons
    assert_screen 'installation-settings-overview-loaded', 220;
}

1;
