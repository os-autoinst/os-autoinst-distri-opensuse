# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup client system for krb5 cryptographic testing
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#51569

use base "consoletest";
use testapi;
use utils;
use lockapi;
use mmapi;
use krb5crypt;    # Import public variables
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    barrier_wait('KRB5_KDC_READY');
    barrier_wait('KRB5_SERVER_READY');
    krb5_init;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
