# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup client system for krb5 cryptographic testing
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#51569

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mmapi;
use krb5crypt;    # Import public variables

sub run {
    select_console 'root-console';

    mutex_wait('CONFIG_READY_KRB5_SERVER');
    krb5_init;
    mutex_create('TEST_DONE_CLIENT');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
