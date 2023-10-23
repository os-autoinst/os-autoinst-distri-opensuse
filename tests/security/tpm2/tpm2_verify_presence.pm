# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test that TPM is present and is working fine.
#
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base 'opensusebasetest';
use serial_terminal 'select_serial_terminal';
use testapi;

sub run {
    select_serial_terminal;

    enter_cmd 'fdectl tpm-present';
    wait_serial 'qr/^TPM self test succeeded\.(\n|.*)+TPM seal\/unseal works$/' ? record_info 'TPM is present and is working fine' : die 'TPM is not present or is not working as expected.';
}

sub test_flags {
    return {fatal => 1};
}

1;
