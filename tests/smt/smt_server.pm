# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: smt SUSEConnect
# Summary: run smt server, check client registration
# - Run basic smt commands
# - Wait for client registraton
# - Check client registration
# Maintainer: QE Core <qe-core@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    mutex_create 'barrier_setup_done';

    select_serial_terminal;

    assert_script_run 'smt-repos -m';
    validate_script_output 'SUSEConnect --status', sub { m/"identifier":"SLES","version":"12\.5","arch":"x86_64","status":"Registered"/ };
    validate_script_output 'smt-repos -o', sub { m/SLES12-SP5-Updates/ };

    barrier_wait 'smt_setup';

    #time for registration of clients

    barrier_wait 'smt_registered';
    validate_script_output 'smt-list-registrations', sub { m/client/ };
    assert_script_run 'smt-job -l';
    barrier_wait 'smt_finished';
}
1;
