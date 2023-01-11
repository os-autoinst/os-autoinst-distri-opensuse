# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Live-CD installer since 2016 seems to have an additional step
# 'network settings' after welcome
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
