# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: mdadm
# Summary: mdadm test, run script creating RAID 0, 1, 5, re-assembling and replacing faulty drive
# - Fetch mdadm.sh from datadir
# - Execute bash mdadm.sh |& tee mdadm.log
# - Upload mdadm.log
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use strict;
use warnings;

sub run {
    select_serial_terminal;

    assert_script_run 'wget ' . data_url('qam/mdadm.sh');
    if (is_sle('<15')) {
        if (script_run('bash mdadm.sh |& tee mdadm.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 200)) {
            record_soft_failure 'bsc#1105628';
            assert_script_run 'bash mdadm.sh |& tee mdadm.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 200;
        }
    }
    else {
        assert_script_run 'bash mdadm.sh |& tee mdadm.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 200;
    }
    upload_logs 'mdadm.log';
}

sub post_fail_hook {
    upload_logs 'mdadm.log';
}

1;
