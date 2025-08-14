# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install Update repos in transactional server
# Maintainer: qac team <qa-c@suse.de>

use base "consoletest";
use testapi;
use qam;
use transactional;
use version_utils 'is_sle_micro';
use serial_terminal;
use utils qw(script_retry fully_patch_system);

sub update_system {
    # By default we use 'up', but this covers also the case of 'patch'
    if (get_var('TRANSACTIONAL_UPDATE_PATCH')) {
        record_info('PATCH', 'Patching system');
        fully_patch_system(trup_call_timeout => 1800);
    } else {
        record_info('UPDATE', 'Updating system');
        trup_call('up', timeout => 1800);
        process_reboot(trigger => 1);
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
        assert_script_run 'journalctl --no-pager -o short-precise | tail -n +2 > /tmp/journal_before';
        upload_logs '/tmp/journal_before';
        assert_script_run 'journalctl --sync --flush --rotate --vacuum-time=1second';
        assert_script_run 'rm /tmp/journal_before';
    }

    update_system;

    # Now we add the test repositories and do a system update
    add_test_repositories;
    record_info('Updates', script_output('zypper lu'));
    update_system;

    # after update, clean the audit log to make sure there aren't any leftovers that were already fixed
    # see poo#169090
    if (is_sle_micro) {
        assert_script_run 'tar czf /tmp/audit_before.tgz /var/log/audit';
        upload_logs '/tmp/audit_before.tgz';
        assert_script_run 'rm -f /var/log/audit/* /tmp/audit_before.tgz';
        # upon reboot, auditd service will be restarted and logfile recreated
    }
    process_reboot(trigger => 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
