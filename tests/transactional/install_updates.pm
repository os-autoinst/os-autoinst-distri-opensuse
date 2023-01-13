# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install Update repos in transactional server
# Maintainer: qac team <qa-c@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use qam;
use transactional;
use version_utils 'is_sle_micro';
use serial_terminal;

sub run {
    my ($self) = @_;

    select_serial_terminal;

    if (is_sle_micro) {
        assert_script_run 'curl -k https://ca.suse.de/certificates/ca/SUSE_Trust_Root.crt -o /etc/pki/trust/anchors/SUSE_Trust_Root.crt';
        assert_script_run 'update-ca-certificates -v';

        # Clean the journal to avoid capturing bugs that are fixed after installing updates
        assert_script_run('journalctl --no-pager -o short-precise | tail -n +2 > /tmp/journal_before');
        upload_logs('/tmp/journal_before');
        assert_script_run('journalctl --sync --flush --rotate --vacuum-time=1second');
        assert_script_run('rm /tmp/journal_before');
    }
    add_test_repositories;
    record_info 'Updates', script_output('zypper lu');
    trup_call 'up', timeout => 1200;
    process_reboot(trigger => 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
