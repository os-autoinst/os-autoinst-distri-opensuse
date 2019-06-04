# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: On IPMI hardware we need to have clear grub
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    my ($self) = shift;

    send_key 'alt-c';
    assert_screen 'inst-overview-options';

    send_key 'alt-b';
    assert_screen 'installation-bootloader-config';
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
