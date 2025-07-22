# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: After installation, enable all repository on a Full-QR system.
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use testapi;
use utils 'zypper_call';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    zypper_call('mr -e -a') if check_var('FLAVOR', 'Full-QR');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
