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

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    assert_screen 'inst-network_settings-livecd';
    # Unpredictable hotkey on kde live distri, click button. See bsc#1045798
    assert_and_click 'next-button';
}

1;
