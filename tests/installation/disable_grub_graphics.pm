# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: On IPMI hardware we need to have clear grub
# Maintainer: Stephan Kulow <coolo@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    my ($self) = shift;

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-c';
        assert_screen 'inst-overview-options';

        send_key 'alt-b';
        assert_screen 'installation-bootloader-config';
    }
    else {
        # Verify Installation Settings overview is displayed as starting point
        assert_screen "installation-settings-overview-loaded";

        # Select section booting on Installation Settings overview (video mode)
        send_key_until_needlematch 'booting-section-selected', 'tab';
        send_key 'ret';
    }
    send_key 'alt-k';
    assert_screen 'installation-bootloader-kernel';
    if (match_has_tag 'graphic-console-enabled') {
        send_key 'alt-g';
    }
    assert_screen 'graphic-console-disabled';
    send_key 'alt-o';
}

sub post_fail_hook {
}

1;
