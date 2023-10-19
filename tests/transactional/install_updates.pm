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
use utils qw(script_retry);

sub soft_fail_rt_scriptlet {
    return if (get_var('FLAVOR') !~ /rt/i);

    if (script_run("grep '%post(kernel-rt-5.14.21-150400.15.46.1.x86_64) scriptlet failed, exit status 1' /var/log/zypp/history") == 0) {
        record_soft_failure('bsc#1213991 - %post(kernel-rt-5.14.21-150400.15.40.1.x86_64) scriptlet failed');
        select_console 'root-console';
        trup_shell 'zypper -n update', timeout => 1800;
    } else {
        die "Transactional update failed with different error cause";
    }
}


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
    add_test_repositories;
    record_info 'Updates', script_output('zypper lu');
    my $ret = trup_call 'up', timeout => 1800, proceed_on_failure => 1;
    soft_fail_rt_scriptlet if ($ret != 0);
    process_reboot(trigger => 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
