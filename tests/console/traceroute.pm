# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: traceroute
# Summary: basic traceroute test
# - install package if not installed
# - check and record version
# - run traceroute to opensuse.org and save logs
# - ensure log file exists and is not empty
# - ensure last log line has target ip
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use utils 'zypper_call';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    my $log = 'traceroute.log';
    my $target = 'opensuse.org';
    my $ip_target = script_output("dig +short A $target");

    zypper_call('in traceroute') if (script_run('rpm -q traceroute'));
    record_info("Version", script_output("rpm -q --qf '%{version}' traceroute"));
    assert_script_run("traceroute -I $target > $log");
    record_info("Traceroute logs", script_output("cat $log"));
    assert_script_run("test -s $log", fail_message => "Log file is empty");
    assert_script_run("tail -n 1 $log | grep -q $ip_target", fail_message => "traceroute did not reach destination ip");
}

1;
