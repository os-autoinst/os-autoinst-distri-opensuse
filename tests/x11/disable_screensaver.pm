# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable screensaver depending on desktop environment
# Maintainer: QE Core <qe-core@suse.de>

use base 'x11test';
use testapi;
use x11utils 'turn_off_screensaver';

sub run {
    select_console 'x11';
    turn_off_screensaver;
}

1;
