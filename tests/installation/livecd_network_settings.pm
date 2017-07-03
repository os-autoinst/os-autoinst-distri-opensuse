# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Live-CD installer since 2016 seems to have an additional step
# 'network settings' after welcome
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen 'inst-network_settings-livecd';
    # For network settings we have different shortcut, see discussion under bsc#1045798
    send_key 'alt-x';
}

1;
# vim: set sw=4 et:
