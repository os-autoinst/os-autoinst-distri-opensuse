# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: traceroute
# Summary: basic traceroute test
# - install package if not installed
# - check and record version
# - run traceroute to suse.com and save logs
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
    zypper_call('in traceroute') if (script_run('rpm -q traceroute'));
    record_info("Version", script_output("rpm -q --qf '%{version}' traceroute"));
    assert_script_run("traceroute -n suse.com > traceroute.log");
    record_info("Traceroute logs", script_output("cat traceroute.log"));
    assert_script_run("test -s traceroute.log", fail_message => "Log file is empty");
}

1;
