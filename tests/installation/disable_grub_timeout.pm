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

    # Verify Installation Settings overview is displayed as starting point
    assert_screen "installation-settings-overview-loaded";

    if (check_var('VIDEOMODE', 'text')) {
        # Select section booting on Installation Settings overview on text mode
        send_key 'alt-c';
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
    # older sle version use 'alt-t;
    my $shortcut = 'alt-r';
    if (check_var('DISTRI', 'sle')) {
        if (!sle_version_at_least('12-SP2')) {
            $shortcut = 'alt-t';
        }
    }
    # openSUSE all supported distributions use 'alt-r'
    wait_screen_change { send_key $shortcut; };

    assert_screen 'installation-bootloader-options';

    # Select Timeout dropdown box and disable
    send_key 'alt-t';
    type_string "-1";

    # ncurses uses blocking modal dialog, so press return is needed
    send_key 'ret' if check_var('VIDEOMODE', 'text');

    wait_still_screen(1);
    save_screenshot;
    send_key $cmd{ok};
}

1;
# vim: set sw=4 et:
