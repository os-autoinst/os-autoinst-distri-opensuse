# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test that the sealed random disk key can be regenerated.
#
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base 'opensusebasetest';
use serial_terminal 'select_serial_terminal';
use transactional 'process_reboot';
use testapi;

sub run {
    select_serial_terminal;

    enter_cmd 'fdectl regenerate-key';
    wait_serial 'Please enter LUKS recovery password:';
    type_string("$testapi::password", lf => 1);
    wait_serial 'Signed PCR policy written.*';

    record_info 'Key successfully regenerated.';

    process_reboot(trigger => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
