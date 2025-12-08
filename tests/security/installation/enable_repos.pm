# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: After installation, enable all repository on a Full flavor system.
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use testapi;
use utils 'zypper_call';
use Utils::Architectures qw(is_ppc64le);
use serial_terminal 'select_serial_terminal';

sub run {
    is_ppc64le() ? select_console('root-console') : select_serial_terminal();
    return unless check_var('FLAVOR', 'Full-QR') || check_var('FLAVOR', 'Full');
    zypper_call('mr -e -a');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
