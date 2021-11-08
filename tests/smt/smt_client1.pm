# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: smt-client SUSEConnect
# Summary: run smt client, register to smt server
# - Install smt client
# - Clean SUSEConnect registration
# - Get registration script and certificate from server
# - Register
# - Check registration
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;

sub run {
    select_console 'root-console';

    zypper_call 'in smt-client';
    assert_script_run 'SUSEConnect --cleanup';
    assert_script_run 'SUSEConnect --status';

    mutex_wait 'barrier_setup_done';
    barrier_wait 'smt_setup';
    #registration of client
    assert_script_run 'wget --no-check-certificate https://SERVER/repo/tools/clientSetup4SMT.sh';
    assert_script_run 'chmod a+x clientSetup4SMT.sh';
    assert_script_run 'echo y | ./clientSetup4SMT.sh --host https://server --regcert https://server/smt.crt';    #needs yes
    assert_script_run 'SUSEConnect -p SLES/12.5/x86_64 --url https://server';

    #checking registration
    validate_script_output 'SUSEConnect --status', sub { m/"identifier":"SLES","version":"12\.5","arch":"x86_64","status":"Registered"/ };
    assert_script_run 'smt-agent';    #client is able to ask for jobs
    validate_script_output 'zypper lr --uri', sub { m/SLES12-SP5-Updates *\| Yes/ };
    validate_script_output 'zypper lr --uri', sub { m/SLES12-SP5-Pool *\| Yes/ };
    barrier_wait 'smt_registered';
}
1;
