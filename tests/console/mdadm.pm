# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: mdadm
# Summary: mdadm test, run script creating RAID 0, 1, 5, re-assembling and replacing faulty drive
# - Fetch mdadm.sh from datadir
# - Execute bash mdadm.sh |& tee mdadm.log
# - Upload mdadm.log
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use Utils::Logging 'save_and_upload_log';
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_serial_terminal;

    zypper_call('in mdadm expect');

    record_info("mdadm build", script_output("rpm -q --qf '%{version}-%{release}' mdadm"));

    assert_script_run 'wget ' . data_url('qam/mdadm.sh');

    my $timeout = 360;
    if (is_sle('<15')) {
        if (script_run('bash mdadm.sh |& tee mdadm.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', $timeout)) {
            record_soft_failure 'bsc#1105628';
            assert_script_run 'bash mdadm.sh |& tee mdadm.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', $timeout;
        }
    }
    else {
        assert_script_run 'bash mdadm.sh |& tee mdadm.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', $timeout;
    }
    upload_logs 'mdadm.log';
}

sub post_fail_hook {
    select_serial_terminal;
    upload_logs 'mdadm.log';
    save_and_upload_log('journalctl --no-pager -ab -o short-precise', 'journal.log');
}

1;
