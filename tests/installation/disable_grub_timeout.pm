# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Disable grub timeout from the Installer
#   in order to ensure tests do not skip over it.
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use utils;

sub run {
    my ($self) = shift;

    if (check_var('ARCH', 's390x')) {
        # on s390x we do not wait for the grub menu or can not handle it like
        # do we on other architectures or backends. Also, we do not have the
        # same problem that we could miss the grub screen with timeout so we
        # skip disabling the grub timeout
        diag 'Skipping disabling grub timeout on s390x as we can not catch the grub screen there';
        return;
    }

    # Verify Installation Settings overview is displayed as starting point
    assert_screen "installation-settings-overview-loaded";

    if (check_var('VIDEOMODE', 'text')) {
        # Select section booting on Installation Settings overview on text mode
        send_key $cmd{change};
        assert_screen 'inst-overview-options';
        wait_screen_change { send_key 'alt-b'; };
    }
    else {
        # Select section booting on Installation Settings overview (video mode)
        send_key_until_needlematch 'booting-section-selected', 'tab';
        assert_screen 'booting-section-selected';
        send_key 'ret';
    }

    # Select bootloader options tab
    $cmd{bootloader} = 'alt-r';    # Value for most products
    if (is_sle) {
        if (!sle_version_at_least('12-SP2') || sle_version_at_least('15')) {
            $cmd{bootloader} = 'alt-t';    # SLE-12 GA & SLE-SP1 & SLE15 use 'alt-t
        }
    }
    elsif (is_leap && leap_version_at_least('15')) {
        $cmd{bootloader} = 'alt-l';
    }
    wait_screen_change { send_key $cmd{bootloader}; };
    assert_screen 'installation-bootloader-options';

    # Select Timeout dropdown box and disable
    send_key 'alt-t';
    my $timeout = "-1";
    # SLE-12 GA only accepts positive integers in range [0,300]
    $timeout = "60" if !(sle_version_at_least('12-SP1'));
    type_string $timeout;

    # ncurses uses blocking modal dialog, so press return is needed
    send_key 'ret' if check_var('VIDEOMODE', 'text');

    wait_still_screen(1);
    save_screenshot;
    send_key $cmd{ok};
}

1;
# vim: set sw=4 et:
