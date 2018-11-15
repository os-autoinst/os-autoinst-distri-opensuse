# SUSE's openQA tests
#
# Author: Gao Zhiyuan <zgao@suse.com>
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Rework the tests layout.
# Maintainer: Gao Zhiyuan <zgao@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run {

    if (check_var('SWITCH_TO_X11', 1)) {
        # install x11 while do not install wayland
        send_key_until_needlematch 'packages-section-selected', 'tab';
        send_key 'ret';
        assert_screen 'pattern_selector';
        send_key 'down';
        send_key 'down';
        send_key 'alt--';
        send_key 'down';
        send_key 'alt-+';
        send_key 'alt-o';
        assert_screen 'installation-settings-overview-loaded';
    }
    # In case of wayland, it would be our default on tumbleweed
    # architecture has to be 64bit-virtio according to qemu drivers as suggested by https://progress.opensuse.org/issues/21786
}

1;
