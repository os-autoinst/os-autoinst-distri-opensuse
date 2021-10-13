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
        send_key_until_needlematch 'security-section-selected', 'tab';
        send_key 'ret';
    }

    send_key 'alt-m';
    send_key_until_needlematch 'security-selinux-enforcing', 'down';
    send_key 'ret' if $textmode;

    send_key $cmd{ok};

    # yast needs some time to think
    assert_screen 'installation-settings-overview-loaded';
}

1;
