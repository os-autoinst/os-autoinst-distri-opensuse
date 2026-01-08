# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Reboot system and reach boot screen.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use testapi;
use power_action_utils 'power_action';

sub run {
    select_console 'root-console';
    power_action('reboot', textmode => 1, keepconsole => 1);
    assert_screen('inst-bootmenu', 300);
}

1;

