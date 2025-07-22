# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tracepath
# Summary: basic tracepath test
# - install iputils if not installed
# - check and record version
# - run tracepath to opensuse.org and save logs
# - ensure log file exists and is not empty
# - ensure tracepath reached destination
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use utils 'zypper_call';
use serial_terminal 'select_serial_terminal';
use version_utils 'is_opensuse';

sub run {
    select_serial_terminal;
    my $log = 'tracepath.log';
    #Targetting WORKER_HOSTNAME on o3 due to firewall strict rules
    my $target = is_opensuse() ? get_required_var('WORKER_HOSTNAME') : 'opensuse.org';

    zypper_call('in iputils') if (script_run('rpm -q iputils'));
    record_info("Version", script_output("rpm -q --qf '%{version}' iputils"));

    assert_script_run("tracepath $target > $log");
    record_info("Tracepath logs", script_output("cat $log"));
    assert_script_run("test -s $log", fail_message => "Log file is empty");
    assert_script_run("! grep -E -q 'failed|Too many hops' $log", fail_message => "tracepath encountered a failure");
    assert_script_run("grep -q 'reached' $log", fail_message => "tracepath did not reach destination $target");
}

1;
