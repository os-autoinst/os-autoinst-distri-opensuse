# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable kdump from the Installer
#   Since 15-SP3, the kdump module is part of the first installer stage
#   and it is enabled by default.
#   We need to disable it for properly testing sysctl settings linked
#   to the RAM amount.
# Maintainer: Julien Adamek <jadamek@suse.com>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    my ($self) = shift;

    # Verify Installation Settings overview is displayed as starting point
    assert_screen "installation-settings-overview-loaded";

    if (check_var('VIDEOMODE', 'text')) {
        # Select section booting on Installation Settings overview on text mode
        send_key $cmd{change};
        assert_screen 'inst-overview-options';
        send_key 'alt-k';
    }
    else {
        # Select section kdump on Installation Settings overview (video mode)
        send_key_until_needlematch 'kdump-section-selected', 'tab', 30;

        send_key 'ret';
    }

    assert_screen 'inst-kdump-settings';
    # Disable kdump
    send_key 'alt-d';
    wait_still_screen(1);

    save_screenshot;
    send_key $cmd{ok};

    # Adapting system setting needs longer time in case of installing/upgrading with multi-addons
    assert_screen 'installation-settings-overview-loaded', 220;
}

1;
