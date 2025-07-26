# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tracepath
# Summary: basic tracepath test
# - install iputils if not installed
# - check and record version
# - run tracepath to suse.com and save logs
# - ensure log file exists and is not empty
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    zypper_call('in iputils') if (script_run('rpm -q iputils'));
    record_info("Version", script_output("rpm -q --qf '%{version}' iputils"));
    assert_script_run("tracepath suse.com > tracepath.log");
    record_info("Tracepath logs", script_output("cat tracepath.log"));
    assert_script_run("test -s tracepath.log", fail_message => "Log file is empty");
}

1;
