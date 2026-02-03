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
use utils qw(zypper_call validate_script_output_retry);
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    my $log = 'traceroute.log';
    my $target = 'opensuse.org';
    my $ip_target = script_output("dig +short A $target");

    zypper_call('in traceroute') if (script_run('rpm -q traceroute'));
    record_info("Version", script_output("rpm -q --qf '%{version}' traceroute"));
    validate_script_output_retry("traceroute -I $target  | tail -n +2 | tee $log", sub { m/$ip_target/ }, retry => 3);
    record_info("Traceroute logs", script_output("cat $log"));
    assert_script_run("test -s $log", fail_message => "Log file is empty");
}

1;
