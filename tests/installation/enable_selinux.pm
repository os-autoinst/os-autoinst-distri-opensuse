# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable SELinux during installation
# Maintainer: Ludwig Nussel <lnussel@suse.com>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use version_utils qw(is_sle_micro is_leap_micro);

sub run {
    my $textmode = check_var('VIDEOMODE', 'text');
    # Verify Installation Settings overview is displayed as starting point
    assert_screen "installation-settings-overview-loaded";

    if ($textmode) {
        # Select section booting on Installation Settings overview on text mode
        send_key $cmd{change};
        assert_screen 'inst-overview-options';
        send_key 'alt-e';
    }
    else {
        # Select section booting on Installation Settings overview (video mode)
        send_key_until_needlematch 'security-section-selected', 'tab', 31, 2;
        send_key 'ret';
    }

    if (is_sle_micro('<5.3') || is_leap_micro('<5.3')) {
        # Combobox for SELinux specifically
        send_key 'alt-m';
        send_key_until_needlematch 'security-selinux-enforcing', 'down';
        send_key 'ret' if $textmode;
    } else {
        # Select SELinux first
        send_key 'alt-s';
        send_key_until_needlematch 'security-module-selinux', 'up';
        send_key 'ret' if $textmode;
        # Switch it into enforcing mode
        send_key 'alt-u';
        send_key_until_needlematch 'security-selinux-enforcing', 'down';
        send_key 'ret' if $textmode;
    }

    send_key $cmd{ok};

    # Make sure the overview is fully loaded and not being recalculated
    wait_still_screen(3);
    assert_screen 'installation-settings-overview-loaded';
}

1;
