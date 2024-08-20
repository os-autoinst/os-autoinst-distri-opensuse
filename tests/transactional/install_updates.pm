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
use utils qw(script_retry fully_patch_system);

sub run {
    my ($self) = @_;

    select_serial_terminal;

    if (is_sle_micro) {
        script_retry('curl -k https://ca.suse.de/certificates/ca/SUSE_Trust_Root.crt -o /etc/pki/trust/anchors/SUSE_Trust_Root.crt', timeout => 100, delay => 30, retry => 5);
        script_retry('pgrep update-ca-certificates', retry => 5, delay => 2, die => 0);
        assert_script_run 'update-ca-certificates -v';

        # Clean the journal to avoid capturing bugs that are fixed after installing updates
        assert_script_run('journalctl --no-pager -o short-precise | tail -n +2 > /tmp/journal_before');
        upload_logs('/tmp/journal_before');
        assert_script_run('journalctl --sync --flush --rotate --vacuum-time=1second');
        assert_script_run('rm /tmp/journal_before');
    }

    # First we update the system
    fully_patch_system(trup_call_timeout => 1800);

    # Now we add the incident repositories and do a zypper patch
    add_test_repositories;
    record_info('Updates', script_output('zypper lu'));
    my $ret = trup_call('up', timeout => 300, proceed_on_failure => 1);
    process_reboot(trigger => 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
