## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Processing grub2 after installation finishes and reboot occurs
# integration test from GitHub.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub run {
    my $timeout = get_var('GRUB_TIMEOUT', 300);
    assert_screen([qw(grub2 grub2-black-screen)], $timeout);
    if (match_has_tag "grub2-black-screen") {
        for (1 .. 9) {
            send_key("up");
            last if check_screen("grub2", 0);
            sleep 0.5;
        }
    }
    send_key 'ret';
}

sub test_flags {
    return {fatal => 1};
}

1;
