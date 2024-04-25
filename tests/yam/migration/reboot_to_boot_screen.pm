# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Reboot system and reach boot screen.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use power_action_utils 'power_action';

sub run {
    select_console 'root-console';
    power_action('reboot', textmode => 1, keepconsole => 1);
    assert_screen('inst-bootmenu', 300);
}

1;

