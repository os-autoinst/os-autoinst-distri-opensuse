# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dig
# Summary: basic dig test
# - install bind-utils if not installed
# - check and record version
# - run dig lookup for opensuse.org and save logs
# - ensure log has NOERROR status and ANSWER SECTION
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    my $target = 'opensuse.org';
    my $target_ip = script_output("dig +short A $target");
    my $log = 'dig.log';

    zypper_call('in bind-utils') if (script_run('rpm -q bind-utils'));
    record_info("Version", script_output("rpm -q --qf '%{version}' bind-utils"));
    assert_script_run("dig $target > $log");
    record_info("dig logs", script_output("cat $log"));
    assert_script_run("grep -q 'status: NOERROR' $log", fail_message => "dig failed to resolve $target");
    assert_script_run("grep -A1 'ANSWER SECTION' $log | grep -q $target_ip", fail_message => "Answer section does not contain target IP $target_ip");
}

1;
