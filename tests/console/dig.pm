# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dig
# Summary: basic dig test
# - install bind-utils if not installed
# - check and record version
# - run dig lookup for suse.com and save logs
# - ensure the log file has status NOERROR
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    zypper_call('in bind-utils') if (script_run('rpm -q bind-utils'));
    record_info("Version", script_output("rpm -q --qf '%{version}' bind-utils"));
    assert_script_run("dig suse.com > dig.log");
    record_info("dig logs", script_output("cat dig.log"));
    assert_script_run("grep -q 'status: NOERROR' dig.log", fail_message => "dig failed to resolve suse.com");
}

1;
