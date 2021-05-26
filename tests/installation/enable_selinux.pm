# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable SELinux during installation

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
}

1;
